# frozen_string_literal: true

RSpec.describe Social::Jobs::SendDueSocialPosts do
  subject(:job) { described_class.new }

  let(:social_post_mutations) { Social::Slice["repos.social_post_mutations"] }
  let(:social_post_queries) { Social::Slice["repos.social_post_queries"] }

  before { connect_social_networks }

  def answer_on_both_networks
    stub_bluesky
    stub_mastodon("110")
  end

  def later(seconds) = allow(Time).to receive(:now).and_return(Time.now + seconds)

  def lose_the_job
    allow(Social::Jobs::DeliverSocialPost).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)
    job.perform
  rescue RedisClient::CannotConnectError
    allow(Social::Jobs::DeliverSocialPost).to receive(:perform_async).and_call_original
  end

  def mastodon = social_account("mastodon")

  def moved_after_reading(**attrs)
    allow(social_post_queries).to receive(:due_scheduled).and_wrap_original do |read, time|
      read.call(time).tap { |due| due.each { social_post_mutations.update(it.id, **attrs) } }
    end

    described_class.new(social_post_queries:).perform
  end

  def orphaned(**)
    queued(targets: %w[mastodon], **).tap { connect_social_networks(mastodon: {}) }
  end

  def queued(targets: %w[mastodon bluesky], posted_at: Time.now - 60, connection_ids: [])
    social_post_mutations.create_with_parts(targets:, posted_at:, connection_ids:, status: "scheduled", parts: %w[one])
  end

  def sent = Social::Jobs::DeliverSocialPost.jobs.map { it["args"] }

  def stalled = described_class::STALLED_AFTER + 60

  it "sends a due social post to every account on the networks it targets" do
    social_post = queued
    job.perform

    expect(sent.sort).to eq([[social_post.id, social_account("bluesky").id], [social_post.id, mastodon.id]].sort)
  end

  it "sends a due social post to the one network it targets" do
    social_post = queued(targets: %w[mastodon])
    job.perform

    expect(sent).to eq([[social_post.id, mastodon.id]])
  end

  it "sends a due social post to each account on a network with two" do
    other = connect_another_mastodon
    social_post = queued(targets: %w[mastodon])
    job.perform

    expect(sent.sort).to eq([[social_post.id, mastodon.id], [social_post.id, other.id]].sort)
  end

  it "sends a due social post only to the accounts it picked" do
    other = connect_another_mastodon
    social_post = queued(targets: %w[mastodon], connection_ids: [other.id])
    job.perform

    expect(sent).to eq([[social_post.id, other.id]])
  end

  it "settles a due social post with no account left on the networks it targets", :aggregate_failures do
    social_post = orphaned
    job.perform

    expect(sent).to be_empty
    expect(social_post_queries.by_id(social_post.id).status).to eq("posted")
  end

  it "fails each network of a due social post with no account left", :aggregate_failures do
    social_post = orphaned
    job.perform

    expect(social_post_queries.by_id(social_post.id).deliveries.map { [it.network, it.failed, it.error] })
      .to eq([["mastodon", true, "No mastodon account is connected"]])
    expect(social_post_queries.failed_statuses).to eq(["posted"])
  end

  it "fails a due social post whose picked accounts are gone" do
    social_post = queued(targets: %w[mastodon], connection_ids: [0])
    job.perform

    expect(social_post_queries.by_id(social_post.id).deliveries.map(&:failed)).to eq([true])
  end

  it "fails a social post with no account left only once" do
    social_post = orphaned
    2.times { job.perform }

    expect(social_post_queries.by_id(social_post.id).deliveries.size).to eq(1)
  end

  it "leaves a social post with no account left alone until it is due" do
    social_post = orphaned(posted_at: Time.now + 3600)
    job.perform

    expect(social_post_queries.by_id(social_post.id).status).to eq("scheduled")
  end

  it "sends to the network still connected when the other is gone", :aggregate_failures do
    social_post = queued
    connect_social_networks(bluesky: {})
    job.perform

    expect(sent).to eq([[social_post.id, mastodon.id]])
    expect(social_post_queries.by_id(social_post.id).status).to eq("scheduled")
  end

  it "leaves a social post scheduled for later alone" do
    queued(posted_at: Time.now + 3600)
    job.perform

    expect(sent).to be_empty
  end

  it "leaves drafts alone" do
    create(:social_post, :draft)
    job.perform

    expect(sent).to be_empty
  end

  it "leaves posted social posts alone" do
    create(:social_post, :posted)
    job.perform

    expect(sent).to be_empty
  end

  {
    "moved back to draft" => { status: "draft" },
    "moved later" => { posted_at: Time.now + 3600 },
  }.each do |what, attrs|
    it "sends nothing for a social post #{what} after the job read it", :aggregate_failures do
      social_post = queued
      moved_after_reading(**attrs)

      expect(sent).to be_empty
      expect(social_post_queries.claimed?(social_post.id)).to be(false)
    end
  end

  it "opens a delivery for each account it sends to" do
    other = connect_another_mastodon
    social_post = queued
    job.perform

    expect(social_post_queries.by_id(social_post.id).deliveries.map(&:connection_id))
      .to contain_exactly(social_account("bluesky").id, mastodon.id, other.id)
  end

  it "never sends the same network twice when run twice" do
    queued(targets: %w[mastodon])
    2.times { job.perform }

    expect(sent.size).to eq(1)
  end

  it "never sends again while a network is still retrying" do
    social_post = queued(targets: %w[mastodon])
    social_post_mutations.record_delivery(social_post.id, mastodon, error: "down")
    job.perform

    expect(sent).to be_empty
  end

  it "sends a network again when its job never reached the queue" do
    social_post = queued(targets: %w[mastodon])
    lose_the_job
    later(stalled)
    job.perform

    expect(sent).to eq([[social_post.id, mastodon.id]])
  end

  it "sends a network again when its job died partway" do
    social_post = queued(targets: %w[mastodon])
    social_post_mutations.record_delivery(social_post.id, mastodon, remote_ids: %w[1])
    later(stalled)
    job.perform

    expect(sent).to eq([[social_post.id, mastodon.id]])
  end

  it "waits for a job that has not had time to start" do
    queued(targets: %w[mastodon])
    job.perform
    later(60)
    job.perform

    expect(sent.size).to eq(1)
  end

  it "never sends again while a network is still retrying, however long ago it failed" do
    social_post = queued(targets: %w[mastodon])
    social_post_mutations.record_delivery(social_post.id, mastodon, error: "down")
    later(stalled)
    job.perform

    expect(sent).to be_empty
  end

  it "sends the network that has no delivery yet" do
    social_post = queued
    social_post_mutations.record_delivery(social_post.id, mastodon, error: "down")
    job.perform

    expect(sent).to eq([[social_post.id, social_account("bluesky").id]])
  end

  it "posts a due social post to every network it targets once the jobs it queued run" do
    answer_on_both_networks
    social_post = queued
    job.perform
    Social::Jobs::DeliverSocialPost.drain

    expect(social_post_queries.by_id(social_post.id).status).to eq("posted")
  end
end

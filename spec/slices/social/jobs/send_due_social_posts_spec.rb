# frozen_string_literal: true

RSpec.describe Social::Jobs::SendDueSocialPosts do
  subject(:job) { described_class.new }

  let(:social_post_repo) { Social::Slice["repos.social_post_repo"] }

  def answer_on_both_networks
    connect_social_networks
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

  def queued(targets: %w[mastodon bluesky], posted_at: Time.now - 60)
    social_post_repo.create_with_parts(targets:, posted_at:, status: "scheduled", parts: %w[one])
  end

  def sent = Social::Jobs::DeliverSocialPost.jobs.map { it["args"] }

  def stalled = described_class::STALLED_AFTER + 60

  it "sends a due social post to every network it targets" do
    social_post = queued
    job.perform

    expect(sent.sort).to eq([[social_post.id, "bluesky"], [social_post.id, "mastodon"]].sort)
  end

  it "sends a due social post to the one network it targets" do
    social_post = queued(targets: %w[mastodon])
    job.perform

    expect(sent).to eq([[social_post.id, "mastodon"]])
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

  it "opens a delivery for each network it sends to" do
    social_post = queued
    job.perform

    expect(social_post_repo.by_id(social_post.id).deliveries.map(&:network)).to eq(%w[bluesky mastodon])
  end

  it "never sends the same network twice when run twice" do
    queued(targets: %w[mastodon])
    2.times { job.perform }

    expect(sent.size).to eq(1)
  end

  it "never sends again while a network is still retrying" do
    social_post = queued(targets: %w[mastodon])
    social_post_repo.record_delivery(social_post.id, "mastodon", error: "down")
    job.perform

    expect(sent).to be_empty
  end

  it "sends a network again when its job never reached the queue" do
    social_post = queued(targets: %w[mastodon])
    lose_the_job
    later(stalled)
    job.perform

    expect(sent).to eq([[social_post.id, "mastodon"]])
  end

  it "sends a network again when its job died partway" do
    social_post = queued(targets: %w[mastodon])
    social_post_repo.record_delivery(social_post.id, "mastodon", remote_ids: %w[1])
    later(stalled)
    job.perform

    expect(sent).to eq([[social_post.id, "mastodon"]])
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
    social_post_repo.record_delivery(social_post.id, "mastodon", error: "down")
    later(stalled)
    job.perform

    expect(sent).to be_empty
  end

  it "sends the network that has no delivery yet" do
    social_post = queued
    social_post_repo.record_delivery(social_post.id, "mastodon", error: "down")
    job.perform

    expect(sent).to eq([[social_post.id, "bluesky"]])
  end

  it "posts a due social post to every network it targets once the jobs it queued run" do
    answer_on_both_networks
    social_post = queued
    job.perform
    Social::Jobs::DeliverSocialPost.drain

    expect(social_post_repo.by_id(social_post.id).status).to eq("posted")
  end
end

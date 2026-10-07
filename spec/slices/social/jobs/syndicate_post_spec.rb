# frozen_string_literal: true

RSpec.describe Social::Jobs::SyndicatePost do
  subject(:job) { described_class.new }

  let(:now) { Time.now.round }
  let(:social_post_queries) { Social::Slice["repos.social_post_queries"] }

  before { connect_social_networks }

  def queued = social_post_queries.queued

  def syndicated(**attributes)
    create(:post, :published, title: "Hello", slug: "hello", syndication_enabled: true,
                              syndication_body: "In my own words", syndication_targets: %w[mastodon bluesky],
                              **attributes)
  end

  it "queues the card's text for every network the card picked, at the time it was handed" do
    job.perform(syndicated.id, (now - 90).to_f)

    expect(queued).to contain_exactly(
      have_attributes(posted_at: now - 90, status: "scheduled", targets: %w[mastodon bluesky],
                      parts: [have_attributes(body: "In my own words", position: 1)]),
    )
  end

  it "links the social post to the blog post" do
    post = syndicated
    job.perform(post.id, now.to_f)

    expect(queued.first.post_id).to eq(post.id)
  end

  it "falls back to the title and the post's URL" do
    post = syndicated(syndication_body: "")
    job.perform(post.id, now.to_f)

    expect(queued.first.parts.first.body).to eq("Hello\n\nhttps://aaronmallen.me/writing/hello")
  end

  it "queues only the networks the card picked" do
    post = syndicated(syndication_targets: %w[mastodon])
    job.perform(post.id, now.to_f)

    expect(queued.first.targets).to eq(%w[mastodon])
  end

  it "leaves out a network with no credentials" do
    connect_social_networks(bluesky: {})
    post = syndicated
    job.perform(post.id, now.to_f)

    expect(queued.first.targets).to eq(%w[mastodon])
  end

  {
    "with syndication off" => -> { syndicated(syndication_enabled: false) },
    "without a network" => -> { syndicated(syndication_targets: []) },
    "with nothing to say" => -> { syndicated(title: "  ", syndication_body: "  ") },
  }.each do |what, post|
    it "queues nothing #{what}" do
      job.perform(instance_exec(&post).id, now.to_f)

      expect(queued).to be_empty
    end
  end

  it "queues nothing when no picked network has credentials" do
    connect_social_networks(bluesky: {}, mastodon: {})
    job.perform(syndicated.id, now.to_f)

    expect(queued).to be_empty
  end

  it "queues nothing twice for the same post" do
    post = syndicated
    2.times { job.perform(post.id, now.to_f) }

    expect(queued.size).to eq(1)
  end

  it "leaves a post alone once its cross-post has been sent" do
    post = syndicated
    create(:social_post, :posted, post_id: post.id)
    job.perform(post.id, now.to_f)

    expect(queued).to be_empty
  end

  it "finishes quietly when the post is gone by the time it runs" do
    expect { job.perform(0, now.to_f) }.not_to raise_error
  end
end

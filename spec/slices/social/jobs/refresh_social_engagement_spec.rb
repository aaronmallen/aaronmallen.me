# frozen_string_literal: true

RSpec.describe Social::Jobs::RefreshSocialEngagement do
  subject(:job) { described_class.new }

  let(:bluesky_post) { bluesky_uri("3kabc") }
  let(:social_post_mutations) { Social::Slice["repos.social_post_mutations"] }
  let(:social_post_queries) { Social::Slice["repos.social_post_queries"] }

  before { connect_social_networks }

  def day = 24 * 60 * 60

  def delivery(social_post, network)
    social_post_queries.by_id(social_post.id).deliveries.find { it.network == network }
  end

  def posted(at: Time.now - day, status: "posted", remote_ids: { "mastodon" => %w[110] }, likes: {})
    social_post = social_post_mutations.create_with_parts(
      targets: remote_ids.keys.empty? ? %w[mastodon] : remote_ids.keys, parts: %w[one], status:, posted_at: at,
    )
    remote_ids.each do |network, ids|
      create(
        :social_post_delivery,
        social_post_id: social_post.id, network:, connection_id: social_account(network).id, remote_ids: ids,
        like_count: likes.fetch(network, 0),
      )
    end

    social_post
  end

  def window = Social::Operations::RefreshSocialEngagement::WINDOW

  describe "a post sent to both networks" do
    let(:social_post) { posted(remote_ids: { "mastodon" => %w[110 111], "bluesky" => [bluesky_post] }) }

    before do
      stub_mastodon_engagement("110", likes: 3, replies: 2, reposts: 1)
      stub_bluesky_engagement(bluesky_post, likes: 9, replies: 8, reposts: 7)
    end

    it "stores the counts Mastodon gives for the first part" do
      social_post
      job.perform

      expect(delivery(social_post, "mastodon")).to have_attributes(like_count: 3, reply_count: 2, repost_count: 1)
    end

    it "stores the counts Bluesky gives" do
      social_post
      job.perform

      expect(delivery(social_post, "bluesky")).to have_attributes(like_count: 9, reply_count: 8, repost_count: 7)
    end

    it "reads Bluesky's counts without signing in" do
      social_post
      job.perform

      expect(a_request(:post, bluesky_url("com.atproto.server.createSession"))).not_to have_been_made
    end
  end

  it "refreshes a post sent a day short of the window" do
    stub_mastodon_engagement("110", likes: 3)
    social_post = posted(at: Time.now - window + day)
    job.perform

    expect(delivery(social_post, "mastodon").like_count).to eq(3)
  end

  it "asks nothing about a post sent before the window" do
    posted(at: Time.now - window - day)
    job.perform

    expect(a_request(:get, /ruby\.social/)).not_to have_been_made
  end

  it "asks nothing about a social post still on its way" do
    posted(status: "scheduled", at: Time.now)
    job.perform

    expect(a_request(:get, /ruby\.social/)).not_to have_been_made
  end

  it "asks nothing of a network that has no remote post yet" do
    posted(remote_ids: { "mastodon" => [] })
    job.perform

    expect(a_request(:get, /ruby\.social/)).not_to have_been_made
  end

  it "keeps the counts of a network that has lost its credentials" do
    likes = { "mastodon" => 4, "bluesky" => 5 }
    social_post = posted(remote_ids: { "mastodon" => %w[110], "bluesky" => [bluesky_post] }, likes:)
    connect_social_networks(bluesky: {}, mastodon: {})
    job.perform

    expect(%w[mastodon bluesky].map { delivery(social_post, it).like_count }).to eq([4, 5])
  end

  describe "a network that errors" do
    let!(:social_post) do
      likes = { "mastodon" => 5, "bluesky" => 6 }
      posted(remote_ids: { "mastodon" => %w[110], "bluesky" => [bluesky_post] }, likes:)
    end

    def bluesky_answers(**response)
      stub_request(:get, "#{SocialNetworks::BLUESKY_PUBLIC}/app.bsky.feed.getPosts")
        .with(query: { uris: bluesky_post }).to_return(**response)
    end

    def mastodon_answers(**response)
      stub_request(:get, "#{SocialNetworks::MASTODON_STATUSES}/110").to_return(**response)
    end

    describe "Mastodon" do
      before { stub_bluesky_engagement(bluesky_post, likes: 9) }

      {
        "breaks" => { status: 500 },
        "throttles the read" => { status: 429 },
        "answers with something that isn't JSON" => { body: "<html></html>",
                                                      headers: { "Content-Type" => "text/html" } },
      }.each do |what, response|
        it "keeps Mastodon's counts and records no error when it #{what}" do
          mastodon_answers(**response)
          job.perform

          expect(delivery(social_post, "mastodon")).to have_attributes(like_count: 5, error: nil)
        end
      end

      it "still refreshes the network that answers" do
        stub_request(:get, "#{SocialNetworks::MASTODON_STATUSES}/110").to_timeout
        job.perform

        expect(delivery(social_post, "bluesky").like_count).to eq(9)
      end
    end

    describe "Bluesky" do
      before { stub_mastodon_engagement("110") }

      {
        "no longer has the post" => { body: { posts: [] }.to_json, headers: { "Content-Type" => "application/json" } },
        "breaks" => { status: 500 },
      }.each do |what, response|
        it "keeps Bluesky's counts when it #{what}" do
          bluesky_answers(**response)
          job.perform

          expect(delivery(social_post, "bluesky").like_count).to eq(6)
        end
      end
    end
  end

  describe "a post sent from a second Mastodon account" do
    let(:social_post) { posted(remote_ids: {}) }

    before do
      stub_request(:get, "https://hachyderm.io/api/v1/statuses/220").to_return(**json_response(favourites_count: 6))
      create(:social_post_delivery, social_post_id: social_post.id, connection_id: connect_another_mastodon.id,
                                    remote_ids: %w[220])
    end

    it "asks the Mastodon server of the account that sent it" do
      job.perform

      expect(delivery(social_post, "mastodon").like_count).to eq(6)
    end
  end

  it "refreshes the posts after one that errors" do
    stub_request(:get, "#{SocialNetworks::MASTODON_STATUSES}/110").to_return(status: 429)
    stub_mastodon_engagement("120", likes: 3)
    later = posted.then { posted(remote_ids: { "mastodon" => %w[120] }) }
    job.perform

    expect(delivery(later, "mastodon").like_count).to eq(3)
  end
end

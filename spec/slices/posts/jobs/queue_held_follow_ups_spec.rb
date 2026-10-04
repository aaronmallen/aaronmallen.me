# frozen_string_literal: true

RSpec.describe Posts::Jobs::QueueHeldFollowUps, :commits, type: :request do
  let(:agent) { Hanami.app["honeybadger.agent"] }
  let(:endpoint) { "https://ada.example/webmention" }
  let(:post_repo) { Posts::Slice["repos.post_repo"] }
  let(:target) { "https://ada.example/notes/1" }

  def card = { syndication_enabled: "1", syndication_body: "In my own words", syndication_targets: %w[mastodon] }

  def cross_posts
    Social::Jobs::SyndicatePost.drain
    Social::Slice["repos.social_post_repo"].queued
  end

  def follow_up_jobs = [Social::Jobs::SyndicatePost, Social::Jobs::SendWebmentions]

  def held = Posts::Slice["relations.held_post_follow_ups"].to_a

  def perform = described_class.new.perform

  def publish
    fields = { title: "Hello", slug: "hello", body: "See [a note](#{target}).", **card }
    post "/admin/posts", _csrf_token: admin_csrf_token, intent: "publish", post: fields
  end

  def queued = follow_up_jobs.flat_map(&:jobs)

  def redis_back = follow_up_jobs.each { allow(it).to receive(:perform_async).and_call_original }

  def redis_down
    follow_up_jobs.each { allow(it).to receive(:perform_async).and_raise(RedisClient::CannotConnectError) }
  end

  def save_published(published)
    fields = { title: "Changed", slug: "hello", body: published.body }
    post "/admin/posts/#{published.id}", _csrf_token: admin_csrf_token, intent: "save", post: fields
  end

  def sent_webmentions
    Social::Jobs::SendWebmentions.drain
    a_request(:post, endpoint).with(body: { source: "https://aaronmallen.me/writing/hello", target: })
  end

  before do
    allow(agent).to receive(:notify)
    connect_social_networks
    resolves_publicly("ada.example")
    stub_request(:get, target).to_return(headers: { "Link" => %(<#{endpoint}>; rel="webmention") }, body: "<p>a</p>")
    stub_request(:post, endpoint).to_return(status: 202)
    sign_in_to_admin
  end

  describe "publishing while Redis is down" do
    before do
      redis_down
      publish
    end

    it "answers as a success", :aggregate_failures do
      expect(last_response.status).to eq(302)
      expect(post_repo.all.last).to have_attributes(status: "published")
    end

    it "tells Honeybadger the queue could not be reached" do
      expect(agent).to have_received(:notify).with(RedisClient::CannotConnectError).twice
    end

    it "holds the cross-post and the webmentions" do
      expect(held.map { it[:follow_up] }).to contain_exactly("syndicate_post", "send_webmentions")
    end

    it "cross-posts once Redis is back" do
      redis_back
      perform

      expect(cross_posts).to contain_exactly(have_attributes(post_id: post_repo.all.last.id, targets: %w[mastodon]))
    end

    it "sends the webmentions once Redis is back" do
      redis_back
      perform

      expect(sent_webmentions).to have_been_made
    end

    it "lets go of what it queued" do
      redis_back
      perform

      expect(held).to be_empty
    end

    it "keeps what it holds while Redis stays down", :aggregate_failures do
      expect { perform }.to raise_error(RedisClient::CannotConnectError)
      expect(held.size).to eq(2)
    end

    it "queues each held follow-up only once when run twice" do
      redis_back
      2.times { perform }

      expect(queued.size).to eq(2)
    end
  end

  describe "saving a published post while Redis is down" do
    let(:published) { create(:post, :published, slug: "hello", body: "See [a note](#{target}).") }

    before do
      redis_down
      save_published(published)
    end

    it "answers as a success", :aggregate_failures do
      expect(last_response.status).to eq(302)
      expect(post_repo.by_id(published.id).title).to eq("Changed")
    end

    it "sends the webmentions once Redis is back" do
      redis_back
      perform

      expect(sent_webmentions).to have_been_made
    end
  end

  describe "publishing a scheduled post while Redis is down" do
    let!(:scheduled) { create(:post, :scheduled, published_at: Time.now.round - 60, syndication_enabled: false) }

    before do
      redis_down
      Posts::Jobs::PublishDuePosts.new.perform
    end

    it "publishes it" do
      expect(post_repo.by_id(scheduled.id).status).to eq("published")
    end

    it "sends its webmentions once Redis is back" do
      redis_back
      perform

      expect(Social::Jobs::SendWebmentions.jobs.map { it["args"] }).to include([scheduled.id])
    end
  end

  it "queues nothing when nothing is held" do
    perform

    expect(queued).to be_empty
  end
end

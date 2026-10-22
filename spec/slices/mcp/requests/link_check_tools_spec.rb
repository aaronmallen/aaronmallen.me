# frozen_string_literal: true

RSpec.describe "MCP link check tools", type: :request do
  def dead = "https://bob.example/gone"

  def post_with(*urls, status: :published)
    create(:post, status, body: ["intro", *urls.map { "See [note](#{it})." }].join("\n\n"))
  end

  def queue_down = API::Structs::Refusal.queue_unavailable.message

  def short_link = Shares::Slice["operations.create_short_link"].call(destination: dead).value!

  describe "check_short_link" do
    def enqueued = Shares::Jobs::CheckShortLinkAgain.jobs.map { it["args"] }

    it "queues the check the admin's Links tab queues", :aggregate_failures do
      link = short_link

      expect(mcp_answer("check_short_link", id: link.id)).to eq("id" => link.id, "status" => "queued")
      expect(enqueued).to eq([[link.id]])
    end

    it "refuses an ID no short link holds", :aggregate_failures do
      mcp_call("check_short_link", id: 999_999)

      expect([mcp_message, enqueued]).to eq(["no short link has the ID 999999", []])
    end

    it "says so when the queue is down" do
      link = short_link
      allow(Shares::Jobs::CheckShortLinkAgain).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)
      mcp_call("check_short_link", id: link.id)

      expect(mcp_message).to eq(queue_down)
    end
  end

  describe "check_post_links" do
    def enqueued = Posts::Jobs::CheckPostLinksAgain.jobs.map { it["args"] }

    it "queues a check of every link in the post", :aggregate_failures do
      post = post_with(dead)

      expect(mcp_answer("check_post_links", id: post.id)).to eq("id" => post.id, "status" => "queued")
      expect(enqueued).to eq([[post.id]])
    end

    it "queues a check of the one link given" do
      post = post_with(dead)
      mcp_call("check_post_links", id: post.id, url: dead)

      expect(enqueued).to eq([[post.id, dead]])
    end

    it "refuses a draft", :aggregate_failures do
      post = post_with(dead, status: :draft)
      mcp_call("check_post_links", id: post.id)

      expect([mcp_message, enqueued]).to eq(["no published blog post has the ID #{post.id}", []])
    end

    it "says so when the queue is down" do
      post = post_with(dead)
      allow(Posts::Jobs::CheckPostLinksAgain).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)
      mcp_call("check_post_links", id: post.id)

      expect(mcp_message).to eq(queue_down)
    end
  end

  describe "run_link_check" do
    it "queues the whole check the nightly job runs", :aggregate_failures do
      expect(mcp_answer("run_link_check")).to eq("status" => "queued")
      expect(Posts::Jobs::CheckPostLinks.jobs.size).to eq(1)
    end

    it "says so when the queue is down" do
      allow(Posts::Jobs::CheckPostLinks).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)
      mcp_call("run_link_check")

      expect(mcp_message).to eq(queue_down)
    end
  end
end

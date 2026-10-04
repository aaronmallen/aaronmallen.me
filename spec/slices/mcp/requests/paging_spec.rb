# frozen_string_literal: true

RSpec.describe "MCP list tool paging", type: :request do
  def earlier(minutes) = Time.now - (minutes * 60)

  def ids(name, key, **) = mcp_answer(name, **).fetch(key).map { it.fetch("id") }

  def range = { from: (today - 1).iso8601, to: today.iso8601 }

  def suggest(post)
    edit = { original: "a", replacement: "b", reason: "typo", part: nil }

    Suggestions::Slice["repos.suggestion_repo"].replace_for_post(post.id, [edit])
  end

  def today = Blog::TimeZone.today

  {
    "list_posts" => {
      key: "posts",
      arguments: -> { {} },
      seed: -> { 1.upto(3) { create(:post, :published, published_at: earlier(it)) } },
    },
    "list_social_posts" => {
      key: "social_posts",
      arguments: -> { range },
      seed: -> { 1.upto(3) { create(:social_post, :posted, posted_at: earlier(it)) } },
    },
    "list_tasks" => {
      key: "tasks",
      arguments: -> { {} },
      seed: -> { 3.times { create(:task) } },
    },
    "list_messages" => {
      key: "messages",
      arguments: -> { range },
      seed: -> { 1.upto(3) { create(:message, received_at: earlier(it)) } },
    },
    "list_webmentions" => {
      key: "webmentions",
      arguments: -> { range },
      seed: -> { 1.upto(3) { create(:webmention, received_at: earlier(it)) } },
    },
    "list_suggestions" => {
      key: "suggestions",
      arguments: -> { range },
      seed: -> { 3.times { suggest(create(:post, body: "a")) } },
    },
    "list_sprints" => {
      key: "sprints",
      arguments: -> { {} },
      seed: -> { 0.upto(2) { create(:sprint, sprint_date: today + it) } },
    },
    "list_tags" => {
      key: "tags",
      arguments: -> { { scope: "public" } },
      seed: -> { 3.times { create(:tag) } },
    },
  }.each do |name, spec|
    describe name do
      let(:arguments) { instance_exec(&spec.fetch(:arguments)) }
      let(:key) { spec.fetch(:key) }

      let!(:whole) do
        instance_exec(&spec.fetch(:seed))
        ids(name, key, **arguments)
      end

      before { lower_page_size(:mcp, to: 2) }

      it "answers one page at most" do
        expect(ids(name, key, **arguments)).to eq(whole.first(2))
      end

      it "says more rows remain and names the page that holds them" do
        expect(mcp_answer(name, **arguments)).to include("partial" => true, "next_page" => 2)
      end

      it "answers the rest from the page it named" do
        expect(ids(name, key, **arguments, page: 2)).to eq(whole.drop(2))
      end

      it "says the last page is whole" do
        expect(mcp_answer(name, **arguments, page: 2).slice("partial", "next_page")).to eq("partial" => false)
      end

      it "answers nothing past the last page" do
        expect(ids(name, key, **arguments, page: 3)).to be_empty
      end

      it "refuses a page before the first" do
        expect(mcp_call(name, **arguments, page: 0).fetch("isError")).to be(true)
      end

      it "refuses a page past the largest" do
        expect(mcp_call(name, **arguments, page: Blog::Constants::INTEGER_MAX + 1).fetch("isError")).to be(true)
      end

      it "answers nothing on a distant page" do
        expect(ids(name, key, **arguments, page: Blog::Constants::INTEGER_MAX)).to be_empty
      end
    end
  end

  describe "a full page" do
    it "answers 100 rows when more remain" do
      101.times { create(:tag) }

      expect(mcp_answer("list_tags", scope: "public")).to include("partial" => true, "next_page" => 2)
        .and(include("tags" => have(100).items))
    end
  end

  describe "the params the tools took before" do
    before { lower_page_size(:mcp, to: 1) }

    it "keeps a status while paging messages" do
      create(:message, :spam, received_at: earlier(1))
      kept = [2, 3].map { create(:message, received_at: earlier(it)).id }

      expect([1, 2].flat_map { ids("list_messages", "messages", **range, status: "unread", page: it) }).to eq(kept)
    end

    it "keeps the statuses while paging tasks" do
      create(:task, :done)
      kept = Array.new(2) { create(:task).id }.reverse

      expect([1, 2].flat_map { ids("list_tasks", "tasks", statuses: %w[open], page: it) }).to eq(kept)
    end

    it "keeps a status while paging webmentions" do
      create(:webmention, :spam, received_at: earlier(1))
      kept = [2, 3].map { create(:webmention, received_at: earlier(it)).id }

      expect([1, 2].flat_map { ids("list_webmentions", "webmentions", **range, status: "pending", page: it) })
        .to eq(kept)
    end

    it "keeps the range while paging posts" do
      create(:post, :published, published_at: days_ago(10))
      kept = [1, 2].map { create(:post, :published, published_at: earlier(it)).id }

      expect([1, 2].flat_map { ids("list_posts", "posts", from: (today - 1).iso8601, page: it) }).to eq(kept)
    end
  end

  describe "list_posts' unsent social posts" do
    before do
      lower_page_size(:mcp, to: 2)
      create(:social_post, :posted)
    end

    let!(:unsent) do
      drafts = Array.new(2) { create(:social_post, :draft).id }.reverse
      queued = [2, 1].map { create(:social_post, :scheduled, posted_at: Time.now + (it * 60 * 60)).id }.reverse

      drafts + queued
    end

    it "pages the drafts, newest first, then the queue, soonest first" do
      expect([1, 2].flat_map { ids("list_posts", "social_posts", page: it) }).to eq(unsent)
    end

    it "says more remain while only social posts do" do
      expect(mcp_answer("list_posts")).to include("posts" => [], "partial" => true, "next_page" => 2)
    end
  end
end

# frozen_string_literal: true

RSpec.describe "MCP record tools", type: :request do
  include Spec::DB::FactoryHelper.new(:record)

  def access_token
    @access_token ||= mcp_connect(
      Spec::DB::Factories[:mcp].create(:oauth_client),
      verifier: Blog::SecretToken.generate,
      scope: "read write publish delete",
    ).fetch("access_token")
  end

  def call_tool(name, **arguments) = rpc("tools/call", { name:, arguments: })

  def content = JSON.parse(message)

  def document = JSON.parse(last_response.body)

  def entries = Record::Slice["relations.journal_entries"]

  def error? = document.dig("result", "isError")

  def journal_page
    get "/admin/journal"
    last_response.body
  end

  def message = document.dig("result", "content").first.fetch("text")

  def rpc(method, params = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}" }
    post "/mcp", JSON.generate({ jsonrpc: "2.0", id: 1, method:, params: }.compact), headers
  end

  def today = Blog::TimeZone.today

  describe "list_commits" do
    def fields_of(commit)
      {
        "id" => commit.id, "sha" => commit.sha, "repo" => "aaronmallen/blog", "branch" => "main",
        "message" => "fix the feed\n\nthe body runs on", "date" => "2026-03-02", "time" => "14:05",
        "additions" => 12, "deletions" => 3,
      }
    end

    def shas = content.fetch("commits").map { it.fetch("sha") }

    def whole_commit
      create(
        :commit,
        repo: "aaronmallen/blog", branch: "main", message: "fix the feed\n\nthe body runs on",
        commit_date: Date.new(2026, 3, 2), commit_time: "14:05", additions: 12, deletions: 3,
      )
    end

    it "answers each commit whole" do
      commit = whole_commit
      call_tool("list_commits", from: "2026-03-01", to: "2026-03-31")

      expect(content.fetch("commits")).to eq([fields_of(commit)])
    end

    it "keeps to the window, newest first" do
      older = create(:commit, commit_date: Date.new(2026, 3, 1))
      newer = create(:commit, commit_date: Date.new(2026, 3, 31))
      create(:commit, commit_date: Date.new(2026, 4, 1))
      call_tool("list_commits", from: "2026-03-01", to: "2026-03-31")

      expect(shas).to eq([newer.sha, older.sha])
    end

    it "narrows to the repositories named, with or without the owner" do
      blog = create(:commit, repo: "aaronmallen/blog", commit_date: Date.new(2026, 3, 2))
      site = create(:commit, repo: "aaronmallen/site", commit_date: Date.new(2026, 3, 3))
      create(:commit, repo: "aaronmallen/other", commit_date: Date.new(2026, 3, 4))
      call_tool("list_commits", from: "2026-03-01", to: "2026-03-31", repos: ["blog", "aaronmallen/site"])

      expect(shas).to eq([site.sha, blog.sha])
    end

    it "says whether it answered the whole window" do
      create(:commit, commit_date: Date.new(2026, 3, 2))
      call_tool("list_commits", from: "2026-03-01", to: "2026-03-31")

      expect(content).to include("count" => 1, "partial" => false)
    end

    it "stops at the row cap and says where to go on" do
      stub_const("Blog::DayWindow::CAP", 2)
      [1, 2, 2, 3].each { create(:commit, commit_date: Date.new(2026, 3, it)) }
      call_tool("list_commits", from: "2026-03-01", to: "2026-03-31")

      expect(content).to include("count" => 3, "partial" => true, "continue_to" => "2026-03-01")
    end

    it "rounds a full window out to the end of its last day" do
      stub_const("Blog::DayWindow::CAP", 2)
      3.times { create(:commit, commit_date: Date.new(2026, 3, 2)) }
      call_tool("list_commits", from: "2026-03-01", to: "2026-03-31")

      expect(content).to include("count" => 3, "partial" => false)
    end

    it "refuses a day it cannot read" do
      call_tool("list_commits", from: "March", to: "2026-03-31")

      expect(message).to eq("give from and to as days, such as 2026-01-01")
    end

    it "refuses a window that runs backwards" do
      call_tool("list_commits", from: "2026-03-31", to: "2026-03-01")

      expect(message).to eq("from comes after to")
    end
  end

  describe "create_journal_entry" do
    it "shows the entry in the admin" do
      call_tool("create_journal_entry", body: "Wrote about abc")

      expect(journal_page).to include("Wrote about abc")
    end

    it "refuses a day after today as an error and saves nothing", :aggregate_failures do
      call_tool("create_journal_entry", body: "Not yet", entry_date: (today + 1).iso8601)

      expect([error?, message, entries.count])
        .to eq([true, "entry_date falls after today; pick today or an earlier day", 0])
    end
  end

  describe "update_journal_entry" do
    it "shows the change in the admin" do
      entry = create(:journal_entry, body: "before")
      call_tool("update_journal_entry", id: entry.id, body: "after the edit")

      expect(journal_page).to include("after the edit")
    end
  end

  describe "delete_journal_entry" do
    it "drops the entry from the admin" do
      entry = create(:journal_entry, body: "gone soon")
      call_tool("delete_journal_entry", id: entry.id)

      expect(journal_page).not_to include("gone soon")
    end
  end

  describe "read_sync_state" do
    def commit_repo = Record::Slice["repos.commit_repo"]

    def fail_commits(day, message)
      sync_state_repo.record_failure(
        Blog::Types::SyncName["commits"], :github_failed, at: Time.utc(2026, 3, day, 8), message:,
      )
    end

    it "answers nothing synced and nothing failing on a fresh site" do
      call_tool("read_sync_state")

      expect(content).to eq("commits_last_synced_at" => nil, "failures" => [])
    end

    it "answers when commits last synced" do
      commit_repo.record_synced_through("aaronmallen/blog", at: Time.utc(2026, 3, 2, 9))
      call_tool("read_sync_state")

      expect(Time.iso8601(content.fetch("commits_last_synced_at"))).to be_within(60).of(Time.now)
    end

    def failing_twice
      {
        "sync" => "commits", "repo" => nil, "reason" => "github_failed", "message" => "503", "count" => 2,
        "failing_since" => "2026-03-01T08:00:00Z", "last_failed_at" => "2026-03-02T08:00:00Z",
      }
    end

    def sync_state_repo = Record::Slice["repos.sync_state_repo"]

    it "answers each failing sync with when it began failing" do
      fail_commits(1, "502")
      fail_commits(2, "503")
      call_tool("read_sync_state")

      expect(content.fetch("failures")).to eq([failing_twice])
    end
  end

  describe "import_commits" do
    def enqueued = Record::Jobs::ImportCommits.jobs

    it "queues the import the admin queues", :aggregate_failures do
      connect_github(client_id: "client-id", client_secret: "client-secret", api_token: "ghp_token")
      call_tool("import_commits")

      expect([content, enqueued.size]).to eq([{ "status" => "queued" }, 1])
    end

    it "refuses when no GitHub token is set", :aggregate_failures do
      disconnect_github
      call_tool("import_commits")

      expect([message, enqueued]).to eq(["no GitHub token is set, so no import can run", []])
    end
  end
end

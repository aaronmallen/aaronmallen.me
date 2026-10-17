# frozen_string_literal: true

RSpec.describe "MCP record tools", type: :request do
  def entries = Record::Slice["relations.journal_entries"]

  def journal_page
    sign_in_to_admin
    get "/admin/journal"
    last_response.body
  end

  def mcp_scopes = %w[read write publish delete]

  def today = Blog::TimeZone.today

  describe "list_commits" do
    def fields_of(commit)
      {
        "id" => commit.id, "sha" => commit.sha, "repo" => "aaronmallen/blog", "branch" => "main",
        "message" => marked("fix the feed\n\nthe body runs on"),
        "date" => "2026-03-02", "time" => "14:05", "additions" => 12, "deletions" => 3,
      }
    end

    def shas = mcp_content.fetch("commits").map { it.fetch("sha") }

    def whole_commit
      create(
        :commit,
        repo: "aaronmallen/blog", branch: "main", message: "fix the feed\n\nthe body runs on",
        commit_date: Date.new(2026, 3, 2), commit_time: "14:05", additions: 12, deletions: 3,
      )
    end

    it "answers each commit whole" do
      commit = whole_commit
      mcp_call("list_commits", from: "2026-03-01", to: "2026-03-31")

      expect(mcp_content.fetch("commits")).to eq([fields_of(commit)])
    end

    it "keeps to the window, newest first" do
      older = create(:commit, commit_date: Date.new(2026, 3, 1))
      newer = create(:commit, commit_date: Date.new(2026, 3, 31))
      create(:commit, commit_date: Date.new(2026, 4, 1))
      mcp_call("list_commits", from: "2026-03-01", to: "2026-03-31")

      expect(shas).to eq([newer.sha, older.sha])
    end

    it "narrows to the repositories named, with or without the owner" do
      blog = create(:commit, repo: "aaronmallen/blog", commit_date: Date.new(2026, 3, 2))
      site = create(:commit, repo: "aaronmallen/site", commit_date: Date.new(2026, 3, 3))
      create(:commit, repo: "aaronmallen/other", commit_date: Date.new(2026, 3, 4))
      mcp_call("list_commits", from: "2026-03-01", to: "2026-03-31", repos: ["blog", "aaronmallen/site"])

      expect(shas).to eq([site.sha, blog.sha])
    end

    it "says whether it answered the whole window" do
      create(:commit, commit_date: Date.new(2026, 3, 2))
      mcp_call("list_commits", from: "2026-03-01", to: "2026-03-31")

      expect(mcp_content).to include("count" => 1, "partial" => false)
    end

    it "stops at the row cap and says where to go on" do
      lower_page_size(:mcp, to: 2)
      [1, 2, 2, 3].each { create(:commit, commit_date: Date.new(2026, 3, it)) }
      mcp_call("list_commits", from: "2026-03-01", to: "2026-03-31")

      expect(mcp_content).to include("count" => 3, "partial" => true, "continue_to" => "2026-03-01")
    end

    it "names the MCP page size in each day-paged tool's description" do
      lower_page_size(:mcp, to: 7)
      mcp_rpc("tools/list")
      paged = %w[list_commits list_journal_entries list_pull_requests read_activity]
      described = mcp_reply.dig("result", "tools").select { paged.include?(it.fetch("name")) }

      expect(described.map { it.fetch("description") }).to all(include("One answer carries about 7 rows"))
    end

    it "rounds a full window out to the end of its last day" do
      lower_page_size(:mcp, to: 2)
      3.times { create(:commit, commit_date: Date.new(2026, 3, 2)) }
      mcp_call("list_commits", from: "2026-03-01", to: "2026-03-31")

      expect(mcp_content).to include("count" => 3, "partial" => false)
    end

    it "refuses a day it cannot read" do
      mcp_call("list_commits", from: "March", to: "2026-03-31")

      expect(mcp_message).to eq("give from and to as days, such as 2026-01-01")
    end

    it "refuses a window that runs backwards" do
      mcp_call("list_commits", from: "2026-03-31", to: "2026-03-01")

      expect(mcp_message).to eq("from comes after to")
    end
  end

  describe "list_pull_requests" do
    def fields_of(pull_request)
      {
        "id" => pull_request.id, "repo" => "someone/else", "number" => 7, "title" => "Import them",
        "description" => "Every one", "url" => "https://github.com/someone/else/pull/7", "state" => "merged",
        "ready_at" => on(2).utc.iso8601, "merged_at" => on(3).utc.iso8601, "closed_at" => nil,
      }
    end

    def numbers = mcp_content.fetch("pull_requests").map { it.fetch("number") }

    def on(day) = Blog::TimeZone.local_time(2026, 3, day, 12)

    def whole_pull_request
      create(
        :pull_request,
        repo: "someone/else", number: 7, title: "Import them", body: "Every one", ready_at: on(2), merged_at: on(3),
      )
    end

    it "answers each pull request whole" do
      merged = whole_pull_request
      mcp_call("list_pull_requests", from: "2026-03-01", to: "2026-03-31")

      expect(trusted(mcp_content.fetch("pull_requests"))).to eq([fields_of(merged)])
    end

    it "keeps to the window, newest first, by the day each one last moved" do
      create(:pull_request, number: 1, ready_at: on(1))
      create(:pull_request, number: 2, ready_at: Blog::TimeZone.local_time(2026, 2, 20), closed_at: on(31))
      create(:pull_request, number: 3, ready_at: on(5), merged_at: Blog::TimeZone.local_time(2026, 4, 1))
      mcp_call("list_pull_requests", from: "2026-03-01", to: "2026-03-31")

      expect(numbers).to eq([2, 1])
    end

    it "dates an open draft by when it opened" do
      create(:pull_request, number: 1, ready_at: nil, opened_at: on(2))
      create(:pull_request, number: 2, ready_at: on(1))
      create(:pull_request, number: 3, ready_at: nil, opened_at: Blog::TimeZone.local_time(2026, 2, 20))
      mcp_call("list_pull_requests", from: "2026-03-01", to: "2026-03-31")

      expect(numbers).to eq([1, 2])
    end

    it "answers a draft as a draft" do
      create(:pull_request, ready_at: nil)
      mcp_call("list_pull_requests", from: today.iso8601, to: today.iso8601)

      expect(mcp_content.fetch("pull_requests").map { it.fetch("state") }).to eq(%w[draft])
    end

    it "stops at the row cap and says where to go on" do
      lower_page_size(:mcp, to: 2)
      [1, 2, 2, 3].each { create(:pull_request, ready_at: on(it)) }
      mcp_call("list_pull_requests", from: "2026-03-01", to: "2026-03-31")

      expect(mcp_content).to include("count" => 3, "partial" => true, "continue_to" => "2026-03-01")
    end

    it "refuses a window that runs backwards" do
      mcp_call("list_pull_requests", from: "2026-03-31", to: "2026-03-01")

      expect(mcp_message).to eq("from comes after to")
    end
  end

  describe "read_pull_request" do
    def opened_fields
      {
        "repo" => "aaronmallen/blog", "number" => 12, "url" => "https://github.com/aaronmallen/blog/pull/12",
        "state" => "open", "ready_at" => "2026-03-02T14:05:00Z", "merged_at" => nil, "closed_at" => nil,
      }
    end

    it "answers an open pull request with its times" do
      opened = create(:pull_request, repo: "aaronmallen/blog", number: 12, ready_at: Time.utc(2026, 3, 2, 14, 5))
      mcp_call("read_pull_request", id: opened.id)

      expect(mcp_content).to include(opened_fields)
    end

    it "answers a pull request closed unmerged as closed" do
      closed = create(:pull_request, closed_at: Time.now)
      mcp_call("read_pull_request", id: closed.id)

      expect(mcp_content.fetch("state")).to eq("closed")
    end

    it "refuses an unknown ID" do
      mcp_call("read_pull_request", id: 999_999)

      expect([mcp_refused?, mcp_message]).to eq([true, "no pull request has the ID 999999"])
    end
  end

  describe "create_journal_entry" do
    it "shows the entry in the admin" do
      mcp_call("create_journal_entry", body: "Wrote about abc")

      expect(journal_page).to include("Wrote about abc")
    end

    it "refuses a day after today as an error and saves nothing", :aggregate_failures do
      mcp_call("create_journal_entry", body: "Not yet", entry_date: (today + 1).iso8601)

      expect([mcp_refused?, mcp_message, entries.count])
        .to eq([true, "entry_date falls after today; pick today or an earlier day", 0])
    end
  end

  describe "update_journal_entry" do
    it "shows the change in the admin" do
      entry = create(:journal_entry, body: "before")
      mcp_call("update_journal_entry", id: entry.id, body: "after the edit")

      expect(journal_page).to include("after the edit")
    end
  end

  describe "delete_journal_entry" do
    it "drops the entry from the admin" do
      entry = create(:journal_entry, body: "gone soon")
      mcp_call("delete_journal_entry", id: entry.id)

      expect(journal_page).not_to include("gone soon")
    end
  end

  describe "read_sync_state" do
    def commit_mutations = Record::Slice["repos.commit_mutations"]

    def fail_commits(day, message)
      sync_state_mutations.record_failure(
        Blog::Types::SyncName["commits"], :github_failed, at: Time.utc(2026, 3, day, 8), message:,
      )
    end

    it "answers nothing synced and nothing failing on a fresh site" do
      mcp_call("read_sync_state")

      expect(mcp_content).to eq("commits_last_synced_at" => nil, "failures" => [])
    end

    it "answers when commits last synced" do
      commit_mutations.record_synced_through("aaronmallen/blog", at: Time.utc(2026, 3, 2, 9))
      mcp_call("read_sync_state")

      expect(Time.iso8601(mcp_content.fetch("commits_last_synced_at"))).to be_within(60).of(Time.now)
    end

    def failing_twice
      {
        "sync" => "commits", "repo" => nil, "reason" => "github_failed", "count" => 2,
        "message" => marked("503"),
        "failing_since" => "2026-03-01T08:00:00Z", "last_failed_at" => "2026-03-02T08:00:00Z",
      }
    end

    def sync_state_mutations = Record::Slice["repos.sync_state_mutations"]

    it "answers each failing sync with when it began failing" do
      fail_commits(1, "502")
      fail_commits(2, "503")
      mcp_call("read_sync_state")

      expect(mcp_content.fetch("failures")).to eq([failing_twice])
    end
  end

  describe "import_commits" do
    def enqueued = Record::Jobs::ImportCommits.jobs

    it "queues the import the admin queues", :aggregate_failures do
      connect_github_token
      mcp_call("import_commits")

      expect([mcp_content, enqueued.size]).to eq([{ "status" => "queued" }, 1])
    end

    it "refuses when GitHub isn't connected", :aggregate_failures do
      disconnect_github
      mcp_call("import_commits")

      expect([mcp_message, enqueued]).to eq(["GitHub isn't connected, so no import can run", []])
    end
  end
end

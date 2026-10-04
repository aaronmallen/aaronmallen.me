# frozen_string_literal: true

RSpec.describe "MCP record tools", type: :request do
  include Spec::DB::FactoryHelper.new(:record)

  def access_token
    @access_token ||= mcp_connect(
      Spec::DB::Factories[:mcp].create(:oauth_client), verifier: MCP::OAuth::Secret.generate, scope: "read write",
    ).fetch("access_token")
  end

  def call_tool(name, **arguments) = rpc("tools/call", { name:, arguments: })

  def content = JSON.parse(message)

  def document = JSON.parse(last_response.body)

  def entries = Record::Slice["relations.journal_entries"]

  def entry_repo = Record::Slice["repos.journal_entry_repo"]

  def error? = document.dig("result", "isError")

  def journal_page
    get "/admin/journal"
    last_response.body
  end

  def link(kind, id, other_kind, other_id)
    Links::Slice["operations.link_records"].call(kind, id, { other_kind:, other_id: }).value!
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

  describe "list_journal_entries" do
    def entry_on(day, time, body) = create(:journal_entry, entry_date: Date.new(2026, 3, day), entry_time: time, body:)

    def rows = content.fetch("entries").map { it.values_at("id", "date", "time", "body", "tags") }

    it "answers each entry in the window with its tags, newest first" do
      older = entry_on(1, "08:00", "first")
      newer = entry_on(2, "21:15", "second").tap { entry_repo.replace_tags(it.id, %w[health]) }
      call_tool("list_journal_entries", from: "2026-03-01", to: "2026-03-31")

      expect(rows).to eq([[newer.id, "2026-03-02", "21:15", "second", %w[health]],
                          [older.id, "2026-03-01", "08:00", "first", []]])
    end

    it "answers the body as the markdown it was written in" do
      entry_on(1, "08:00", "a **bold** day\n\n- one")
      call_tool("list_journal_entries", from: "2026-03-01", to: "2026-03-31")

      expect(rows.map { it[3] }).to eq(["a **bold** day\n\n- one"])
    end

    it "leaves out an entry past the window" do
      create(:journal_entry, entry_date: Date.new(2026, 4, 1))
      call_tool("list_journal_entries", from: "2026-03-01", to: "2026-03-31")

      expect(content.fetch("entries")).to be_empty
    end

    it "stops at the row cap and says where to go on" do
      stub_const("Blog::DayWindow::CAP", 1)
      create(:journal_entry, entry_date: Date.new(2026, 3, 1))
      create(:journal_entry, entry_date: Date.new(2026, 3, 2))
      call_tool("list_journal_entries", from: "2026-03-01", to: "2026-03-31")

      expect(content).to include("count" => 1, "partial" => true, "continue_to" => "2026-03-01")
    end

    it "refuses a window that runs backwards" do
      call_tool("list_journal_entries", from: "2026-03-31", to: "2026-03-01")

      expect(message).to eq("from comes after to")
    end
  end

  describe "read_commit" do
    it "answers the commit whole, as list_commits gives it" do
      commit = create(:commit, message: "fix the feed\n\nthe body runs on", commit_date: Date.new(2026, 3, 2))
      call_tool("list_commits", from: "2026-03-02", to: "2026-03-02")
      listed = content.fetch("commits").first
      call_tool("read_commit", id: commit.id)

      expect(content).to eq(listed.merge("record_links" => {}))
    end

    it "answers the records linked to the commit, grouped by kind" do
      commit = create(:commit)
      entry = create(:journal_entry)
      link("commit", commit.id, "journal_entry", entry.id)
      call_tool("read_commit", id: commit.id)

      expect(content.fetch("record_links")).to match("journal_entry" => [include("id" => entry.id)])
    end

    it "calls an unknown ID an error" do
      call_tool("read_commit", id: 404)

      expect([error?, message]).to eq([true, "no commit has the ID 404"])
    end
  end

  describe "read_journal_entry" do
    it "answers the entry with its tags" do
      entry = create(:journal_entry, entry_date: Date.new(2026, 3, 2), entry_time: "09:30", body: "a day")
      entry_repo.replace_tags(entry.id, %w[health ruby])
      call_tool("read_journal_entry", id: entry.id)

      expect(content.values_at("date", "time", "body", "tags", "record_links"))
        .to eq(["2026-03-02", "09:30", "a day", %w[health ruby], {}])
    end

    it "answers when the entry was written and when it last changed, in UTC" do
      entry = create(:journal_entry, created_at: Time.utc(2026, 3, 2, 9, 30), updated_at: Time.utc(2026, 3, 4, 18))
      call_tool("read_journal_entry", id: entry.id)

      expect(content.values_at("created_at", "updated_at")).to eq(%w[2026-03-02T09:30:00Z 2026-03-04T18:00:00Z])
    end

    it "answers the body as the markdown it was written in" do
      entry = create(:journal_entry, body: "a **bold** day\n\n- one")
      call_tool("read_journal_entry", id: entry.id)

      expect(content.fetch("body")).to eq("a **bold** day\n\n- one")
    end

    it "calls an unknown ID an error" do
      call_tool("read_journal_entry", id: 404)

      expect(message).to eq("no journal entry has the ID 404")
    end
  end

  describe "create_journal_entry" do
    it "saves the entry on today with its tags" do
      call_tool("create_journal_entry", body: "Wrote about abc", tags: %w[ruby Health])

      expect(content).to include("date" => today.iso8601, "body" => "Wrote about abc", "tags" => %w[health ruby])
    end

    it "shows the entry in the admin" do
      call_tool("create_journal_entry", body: "Wrote about abc")

      expect(journal_page).to include("Wrote about abc")
    end

    it "lands on the earlier day it names" do
      call_tool("create_journal_entry", body: "Back then", entry_date: (today - 3).iso8601)

      expect(entries.one[:entry_date]).to eq(today - 3)
    end

    it "refuses a day after today, as the admin does", :aggregate_failures do
      call_tool("create_journal_entry", body: "Not yet", entry_date: (today + 1).iso8601)

      expect([error?, message, entries.count])
        .to eq([true, "entry_date falls after today; pick today or an earlier day", 0])
    end

    it "refuses a blank body" do
      call_tool("create_journal_entry", body: "  ")

      expect(message).to eq("body needs a character that is not a space")
    end

    it "refuses a tag the admin would refuse" do
      call_tool("create_journal_entry", body: "Tagged", tags: ["no_good"])

      expect(message).to eq("tags take lowercase letters, numbers and single dashes in each tag")
    end

    it "refuses a body holding a NUL" do
      call_tool("create_journal_entry", body: "a\u0000b")

      expect(message).to eq("body holds a control character")
    end

    it "says it saved nothing when the save fails for a reason it does not know" do
      failing = instance_double(Record::Operations::SaveJournalEntry, call: Dry::Monads::Failure(:unexpected))
      replace_component("record.operations.save_journal_entry", failing)
      call_tool("create_journal_entry", body: "Lost")

      expect(message).to eq("could not save the journal entry")
    end
  end

  describe "update_journal_entry" do
    let(:entry) { create(:journal_entry, entry_date: Date.new(2026, 3, 2), body: "before") }

    before { entry_repo.replace_tags(entry.id, %w[health]) }

    it "changes the body and keeps the tags it was not given" do
      call_tool("update_journal_entry", id: entry.id, body: "after")

      expect(content).to include("body" => "after", "tags" => %w[health], "date" => "2026-03-02")
    end

    it "changes the tags and keeps the body it was not given" do
      call_tool("update_journal_entry", id: entry.id, tags: %w[ruby])

      expect(entry_repo.by_id(entry.id)).to have_attributes(body: "before", tags: [have_attributes(name: "ruby")])
    end

    it "clears the tags on an empty list" do
      call_tool("update_journal_entry", id: entry.id, tags: [])

      expect(content.fetch("tags")).to eq([])
    end

    it "shows the change in the admin" do
      call_tool("update_journal_entry", id: entry.id, body: "after the edit")

      expect(journal_page).to include("after the edit")
    end

    it "refuses a blank body and keeps the old one", :aggregate_failures do
      call_tool("update_journal_entry", id: entry.id, body: " ")

      expect([message, entry_repo.by_id(entry.id).body]).to eq(["body needs a character that is not a space", "before"])
    end

    it "calls an unknown ID an error" do
      call_tool("update_journal_entry", id: entry.id + 1000, body: "after")

      expect(message).to eq("no journal entry has the ID #{entry.id + 1000}")
    end
  end

  describe "delete_journal_entry" do
    it "removes the entry", :aggregate_failures do
      entry = create(:journal_entry, body: "gone soon")
      call_tool("delete_journal_entry", id: entry.id)

      expect([content, entries.count]).to eq([{ "id" => entry.id, "deleted" => true }, 0])
    end

    it "drops the entry from the admin" do
      entry = create(:journal_entry, body: "gone soon")
      call_tool("delete_journal_entry", id: entry.id)

      expect(journal_page).not_to include("gone soon")
    end

    it "calls an unknown ID an error" do
      call_tool("delete_journal_entry", id: 404)

      expect(message).to eq("no journal entry has the ID 404")
    end
  end

  describe "read_sync_state" do
    def commit_repo = Record::Slice["repos.commit_repo"]

    def fail_commits(day, message)
      sync_state_repo.record_failure(
        Record::Repos::SyncStateRepo::COMMITS, :github_failed, at: Time.utc(2026, 3, day, 8), message:,
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

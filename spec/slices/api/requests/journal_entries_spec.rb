# frozen_string_literal: true

RSpec.describe "API journal entries", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(verb, path, body = nil, token: api_token)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    public_send(verb, "/api/v1/journal_entries#{path}", body, headers)
    JSON.parse(last_response.body)
  end

  def create_entry(fields) = call_api(:post, "", JSON.generate(fields))

  def delete_entry(id) = call_api(:delete, "/#{id}")

  def entries = Record::Slice["relations.journal_entries"]

  def entry_repo = Record::Slice["repos.journal_entry_repo"]

  def link(kind, id, other_kind, other_id)
    Links::Slice["operations.link_records"].call(kind, id, { other_kind:, other_id: }).value!
  end

  def list(**window) = call_api(:get, "", window)

  def read(id) = call_api(:get, "/#{id}")

  def status = last_response.status

  def today = Blog::TimeZone.today

  def update_entry(id, fields) = call_api(:patch, "/#{id}", JSON.generate(fields))

  describe "GET /api/v1/journal_entries" do
    def entry_on(day, time, body) = create(:journal_entry, entry_date: Date.new(2026, 3, day), entry_time: time, body:)

    def march = list(from: "2026-03-01", to: "2026-03-31")

    def rows = march.fetch("entries").map { it.values_at("id", "date", "time", "body", "tags") }

    it "lists the window's entries, newest first, with their tags" do
      older = entry_on(1, "08:00", "first")
      newer = entry_on(2, "21:15", "second")
      entry_repo.replace_tags(newer.id, %w[health])

      expect(rows).to eq([[newer.id, "2026-03-02", "21:15", "second", %w[health]],
                          [older.id, "2026-03-01", "08:00", "first", []]])
    end

    it "gives each entry when it was written and when it last changed" do
      stamps = { created_at: Time.utc(2026, 3, 2, 9), updated_at: Time.utc(2026, 3, 5, 12) }
      create(:journal_entry, entry_date: Date.new(2026, 3, 2), **stamps)

      expect(march.fetch("entries").map { it.values_at("created_at", "updated_at") })
        .to eq([%w[2026-03-02T09:00:00Z 2026-03-05T12:00:00Z]])
    end

    it "describes the window with a 200" do
      window = { "from" => "2026-03-01", "to" => "2026-03-31", "count" => 0, "partial" => false, "entries" => [] }

      expect([march, status]).to eq([window, 200])
    end

    it "leaves out entries outside the window" do
      create(:journal_entry, entry_date: Date.new(2026, 4, 1))

      expect(march.fetch("entries")).to be_empty
    end

    it "stops at the row cap and says where to go on" do
      stub_const("Blog::DayWindow::CAP", 1)
      entry_on(1, "08:00", "first")
      entry_on(2, "08:00", "second")

      expect(march).to include("count" => 1, "partial" => true, "continue_to" => "2026-03-01")
    end

    it "refuses a window that runs backwards with a 422" do
      refusal = { "error" => "invalid", "message" => "from comes after to",
                  "errors" => { "from" => ["from comes after to"], "to" => ["from comes after to"] } }

      expect([list(from: "2026-03-31", to: "2026-03-01"), status]).to eq([refusal, 422])
    end

    it "refuses a window with no end" do
      expect([list(from: "2026-03-01").fetch("errors"), status]).to eq([{ "to" => ["to is missing"] }, 422])
    end

    it "refuses a request with no token" do
      call_api(:get, "", { from: "2026-03-01", to: "2026-03-31" }, token: nil)

      expect(status).to eq(401)
    end

    it "tells every cache not to store the answer" do
      march

      expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
    end
  end

  describe "GET /api/v1/journal_entries/:id" do
    it "answers the entry with its tags" do
      entry = create(:journal_entry, entry_date: Date.new(2026, 3, 2), entry_time: "09:30", body: "a day")
      entry_repo.replace_tags(entry.id, %w[health ruby])

      expect(read(entry.id).except("id", "created_at", "updated_at")).to eq(
        "date" => "2026-03-02", "time" => "09:30", "body" => "a day", "tags" => %w[health ruby], "record_links" => {},
      )
    end

    it "answers when the entry was written and when it last changed, in UTC" do
      entry = create(:journal_entry, created_at: Time.utc(2026, 3, 2, 9, 30), updated_at: Time.utc(2026, 3, 4, 18))

      expect(read(entry.id).values_at("created_at", "updated_at"))
        .to eq(%w[2026-03-02T09:30:00Z 2026-03-04T18:00:00Z])
    end

    it "answers the records linked to the entry, grouped by kind" do
      entry = create(:journal_entry)
      task = create(:task, title: "Move the server")
      link("journal_entry", entry.id, "task", task.id)

      expect(read(entry.id).fetch("record_links"))
        .to match("task" => [include("kind" => "task", "id" => task.id, "title" => "Move the server")])
    end

    it "answers the same record links as read_journal_entry" do
      entry = create(:journal_entry)
      link("journal_entry", entry.id, "post", create(:post).id)

      expect(read(entry.id).fetch("record_links"))
        .to eq(mcp_answer("read_journal_entry", id: entry.id).fetch("record_links"))
    end

    it "answers an unknown ID with a 404" do
      expect([read(404), status])
        .to eq([{ "error" => "not_found", "message" => "no journal entry has the ID 404" }, 404])
    end

    it "refuses an ID that is not a number with a 422" do
      expect([read("abc").fetch("errors").keys, status]).to eq([%w[id], 422])
    end
  end

  describe "POST /api/v1/journal_entries" do
    it "saves the entry on today with its tags and answers 201" do
      expect([create_entry(body: "Wrote about abc", tags: %w[ruby Health]), status])
        .to match([include("date" => today.iso8601, "body" => "Wrote about abc", "tags" => %w[health ruby]), 201])
    end

    it "lands on the earlier day it names" do
      create_entry(body: "Back then", entry_date: (today - 3).iso8601)

      expect(entries.one[:entry_date]).to eq(today - 3)
    end

    it "refuses a blank body with a 422 naming the field" do
      blank = "body needs a character that is not a space"
      refusal = { "error" => "invalid", "message" => blank, "errors" => { "body" => [blank] } }

      expect([create_entry(body: "  "), status]).to eq([refusal, 422])
    end

    it "refuses a day after today and saves nothing" do
      create_entry(body: "Not yet", entry_date: (today + 1).iso8601)

      expect([status, entries.count]).to eq([422, 0])
    end

    it "refuses a body that is not a string" do
      expect([create_entry(body: 5).fetch("errors").keys, status]).to eq([%w[body], 422])
    end

    it "refuses a field it does not take" do
      expect([create_entry(body: "fine", mood: "good").fetch("errors").keys, status]).to eq([%w[mood], 422])
    end

    it "refuses an entry with no body" do
      expect(create_entry(tags: %w[ruby]).fetch("errors")).to eq("body" => ["body is missing"])
    end

    it "refuses a body that is not JSON with a 400" do
      expect([call_api(:post, "", "{nope"), status])
        .to eq([{ "error" => "invalid_json", "message" => "the body takes a JSON object" }, 400])
    end

    it "refuses a JSON body that is not an object with a 400" do
      expect([call_api(:post, "", "[]").fetch("error"), status]).to eq(["invalid_json", 400])
    end

    it "answers a failure it did not expect with a 500" do
      failing = instance_double(Record::Operations::SaveJournalEntry, call: Dry::Monads::Failure(:unexpected))
      replace_component("record.operations.save_journal_entry", failing)

      expect([create_entry(body: "Lost"), status])
        .to eq([{ "error" => "failed", "message" => "could not save the journal entry" }, 500])
    end
  end

  describe "PATCH /api/v1/journal_entries/:id" do
    let(:entry) { create(:journal_entry, entry_date: Date.new(2026, 3, 2), body: "before") }

    before { entry_repo.replace_tags(entry.id, %w[health]) }

    it "changes the body and keeps the tags and date" do
      expect(update_entry(entry.id, body: "after"))
        .to include("body" => "after", "tags" => %w[health], "date" => "2026-03-02")
    end

    it "moves the updated stamp and keeps the created one" do
      written = Time.utc(2026, 3, 2, 9)
      entries.where(id: entry.id).update(created_at: written, updated_at: written)
      updated = update_entry(entry.id, body: "after")

      expect([updated.fetch("created_at"), Time.iso8601(updated.fetch("updated_at")) > written])
        .to eq(["2026-03-02T09:00:00Z", true])
    end

    it "changes the tags and keeps the body" do
      update_entry(entry.id, tags: %w[ruby])

      expect(entry_repo.by_id(entry.id)).to have_attributes(body: "before", tags: [have_attributes(name: "ruby")])
    end

    it "clears the tags on an empty list" do
      expect(update_entry(entry.id, tags: []).fetch("tags")).to eq([])
    end

    it "refuses a blank body with a 422 and keeps the old one" do
      update_entry(entry.id, body: " ")

      expect([status, entry_repo.by_id(entry.id).body]).to eq([422, "before"])
    end

    it "answers an unknown ID with a 404" do
      update_entry(entry.id + 1000, body: "after")

      expect(status).to eq(404)
    end
  end

  describe "DELETE /api/v1/journal_entries/:id" do
    it "removes the entry" do
      entry = create(:journal_entry)

      expect([delete_entry(entry.id), entries.count]).to eq([{ "id" => entry.id, "deleted" => true }, 0])
    end

    it "answers an unknown ID with a 404" do
      expect([delete_entry(404), status])
        .to eq([{ "error" => "not_found", "message" => "no journal entry has the ID 404" }, 404])
    end
  end

  describe "the MCP tools" do
    it "list as list_journal_entries does" do
      create(:journal_entry, entry_date: Date.new(2026, 3, 2), tags: %w[health])
      window = { from: "2026-03-01", to: "2026-03-31" }

      expect(list(**window)).to eq(mcp_answer("list_journal_entries", **window))
    end

    it "read as read_journal_entry does" do
      entry = create(:journal_entry, tags: %w[ruby])

      expect(read(entry.id)).to eq(mcp_answer("read_journal_entry", id: entry.id))
    end

    it "create as create_journal_entry does" do
      varying = %w[id time created_at updated_at]
      fields = { body: "the same", entry_date: (today - 1).iso8601, tags: %w[ruby] }
      created = create_entry(fields)

      expect(mcp_answer("create_journal_entry", **fields).except(*varying)).to eq(created.except(*varying))
    end

    it "update as update_journal_entry does" do
      entry = create(:journal_entry, tags: %w[health])
      updated = update_entry(entry.id, body: "after", tags: %w[ruby])

      expect(mcp_answer("update_journal_entry", id: entry.id, body: "after", tags: %w[ruby]).except("updated_at"))
        .to eq(updated.except("updated_at"))
    end

    it "delete as delete_journal_entry does" do
      ids = [create(:journal_entry).id, create(:journal_entry).id]
      deleted = delete_entry(ids.first)

      expect(mcp_answer("delete_journal_entry", id: ids.last)).to eq(deleted.merge("id" => ids.last))
    end

    it "refuse with the message the endpoint gives" do
      refused = create_entry(body: " ")

      expect(mcp_text("create_journal_entry", body: " ")).to eq(refused.fetch("message"))
    end
  end
end

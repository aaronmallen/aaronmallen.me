# frozen_string_literal: true

RSpec.describe "API review note", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def headers(token)
    found = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    token ? found.merge("HTTP_AUTHORIZATION" => "Bearer #{token}") : found
  end

  def note(period = "week", starts_on = Date.new(2026, 9, 14)) = review_note_queries.note(period, starts_on)

  def read(**query)
    get "/api/v1/review", query, headers(api_token)
    JSON.parse(last_response.body)
  end

  def refusal(message) = { "error" => "invalid", "message" => message, "errors" => { "body" => [message] } }

  def review_note_queries = Record::Slice["repos.review_note_queries"]

  def save(token: api_token, **fields)
    post "/api/v1/review/note", JSON.generate(fields), headers(token)
    JSON.parse(last_response.body)
  end

  def shown(saved)
    { "body" => saved.body, **%w[created_at updated_at].to_h { [it, saved.public_send(it).utc.iso8601] } }
  end

  def status = last_response.status

  def stored_notes = Record::Slice["relations.review_notes"].to_a

  describe "GET /api/v1/review" do
    it "gives a null note when the period has none" do
      expect(read(day: "2026-09-16").fetch("note")).to be_nil
    end

    it "gives the week's note" do
      save(day: "2026-09-16", body: "good week")

      expect(read(day: "2026-09-20").fetch("note")).to eq(shown(note))
    end

    it "gives the month only its own note" do
      save(day: "2026-09-16", body: "good week")

      expect(read(period: "month", day: "2026-09-16").fetch("note")).to be_nil
    end

    it "gives the note the admin saved" do
      sign_in_to_admin
      fields = { period: "month", day: "2026-09-30", note: { body: "good month" } }
      post "/admin/review/note", _csrf_token: admin_csrf_token, **fields

      expect(read(period: "month", day: "2026-09-02").dig("note", "body")).to eq("good month")
    end
  end

  describe "POST /api/v1/review/note" do
    it "keeps the note for the week that holds the day" do
      save(day: "2026-09-16", body: "good week")

      expect(note&.body).to eq("good week")
    end

    it "answers 200 with the note and the period it landed in, trimmed" do
      answered = save(day: "2026-09-16", body: "  good week  ")

      expect([answered, status])
        .to eq([{ "period" => "week", "from" => "2026-09-14", "to" => "2026-09-20", **shown(note) }, 200])
    end

    it "keeps a month's note for the month" do
      answered = save(period: "month", day: "2026-09-16", body: "good month")

      expect([answered.values_at("period", "from", "to"), note("month", Date.new(2026, 9, 1))&.body])
        .to eq([%w[month 2026-09-01 2026-09-30], "good month"])
    end

    it "replaces the period's note in place of adding a second" do
      save(day: "2026-09-14", body: "good week")
      save(day: "2026-09-20", body: "great week")

      expect(stored_notes.map { it[:body] }).to eq(["great week"])
    end

    it "refuses a blank note with a 422 and keeps the old one", :aggregate_failures do
      save(day: "2026-09-16", body: "good week")

      expect([save(day: "2026-09-16", body: " \n "), status])
        .to eq([refusal("body needs a character that is not a space"), 422])
      expect(note.body).to eq("good week")
    end

    it "refuses an empty note with a 422" do
      expect([save(day: "2026-09-16", body: ""), status])
        .to eq([refusal("body needs a character that is not a space"), 422])
    end

    it "refuses a note with a control character" do
      expect(save(day: "2026-09-16", body: "good\u0007week")).to eq(refusal("body holds a control character"))
    end

    it "refuses a day it cannot read with a 422 and saves nothing" do
      message = "give the day as a date, such as 2026-01-01"

      expect([save(day: "2026-13-40", body: "good week"), status, stored_notes])
        .to eq([{ "error" => "invalid", "message" => message, "errors" => { "day" => [message] } }, 422, []])
    end

    it "refuses a period other than week or month" do
      expect([save(period: "year", day: "2026-09-16", body: "good").fetch("errors").keys, status])
        .to eq([%w[period], 422])
    end

    it "refuses a request with no day or body" do
      expect(save.fetch("errors")).to eq("day" => ["day is missing"], "body" => ["body is missing"])
    end

    it "answers 500 when the save fails some other way" do
      failing = instance_double(Record::Operations::SaveReviewNote, call: Dry::Monads::Failure(:locked))
      replace_component("record.operations.save_review_note", failing)

      expect([save(day: "2026-09-16", body: "good week"), status])
        .to eq([{ "error" => "failed", "message" => "could not save the review note" }, 500])
    end

    it "refuses a request with no token" do
      save(token: nil, day: "2026-09-16", body: "good week")

      expect([status, stored_notes]).to eq([401, []])
    end
  end

  describe "the MCP tools" do
    it "save as save_review_note does" do
      answered = save(period: "month", day: "2026-09-16", body: "the same")
      tool = mcp_answer("save_review_note", period: "month", day: "2026-09-16", body: "the same")

      expect(unstamped(tool)).to eq(unstamped(answered))
    end

    it "save a note read_review then returns" do
      mcp_answer("save_review_note", day: "2026-09-16", body: "good week")

      expect(trusted(mcp_answer("read_review", day: "2026-09-16")).dig("note", "body")).to eq("good week")
    end

    it "refuse a blank note with the message the endpoint gives" do
      refused = save(day: "2026-09-16", body: " ")

      expect(mcp_text("save_review_note", day: "2026-09-16", body: " ")).to eq(refused.fetch("message"))
    end
  end
end

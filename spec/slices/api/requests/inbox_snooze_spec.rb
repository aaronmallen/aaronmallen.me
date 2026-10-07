# frozen_string_literal: true

RSpec.describe "API inbox snooze", type: :request do
  let(:message) { create(:message, subject: "message") }
  let(:ends_at) { Time.now.floor + 3600 }

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def inbox_titles
    get "/api/v1/inbox", {}, { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    JSON.parse(last_response.body).fetch("inbox").map { it.fetch("title") }
  end

  def snooze(**body)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    post "/api/v1/inbox/snooze", JSON.generate(body), headers
    JSON.parse(last_response.body)
  end

  def status = last_response.status

  def synced = create(:task, :external).tap { create(:task_source, task: it) }

  it "snoozes a row and drops it from the inbox", :aggregate_failures do
    reply = snooze(kind: "message", id: message.id, snoozed_until: ends_at.iso8601)

    expect(reply).to eq("kind" => "message", "id" => message.id, "snoozed_until" => ends_at.utc.iso8601)
    expect(inbox_titles).to be_empty
  end

  it "snoozes each kind the inbox lists" do
    rows = { "task" => synced, "webmention" => create(:webmention) }
    rows.each { |kind, record| snooze(kind:, id: record.id, snoozed_until: ends_at.iso8601) }

    expect(inbox_titles).to be_empty
  end

  it "refuses a time in the past", :aggregate_failures do
    reply = snooze(kind: "message", id: message.id, snoozed_until: (Time.now - 60).iso8601)

    expect(status).to eq(422)
    expect(reply.dig("errors", "snoozed_until")).to eq(["snoozed_until must be in the future"])
  end

  it "refuses what is not a time" do
    snooze(kind: "message", id: message.id, snoozed_until: "soon")

    expect(status).to eq(422)
  end

  it "answers 404 for a row that isn't there" do
    snooze(kind: "message", id: 999_999, snoozed_until: ends_at.iso8601)

    expect(status).to eq(404)
  end

  it "answers the MCP tool the same way" do
    reply = trusted(mcp_answer("snooze_inbox_row", kind: "message", id: message.id, snoozed_until: ends_at.iso8601))

    expect(reply).to eq("kind" => "message", "id" => message.id, "snoozed_until" => ends_at.utc.iso8601)
  end
end

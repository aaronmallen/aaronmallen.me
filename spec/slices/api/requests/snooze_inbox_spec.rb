# frozen_string_literal: true

RSpec.describe "API snooze inbox", type: :request do
  let(:ends_at) { Time.now.floor + 3600 }
  let(:message) { create(:message) }
  let(:task) { create(:task, :external).tap { create(:task_source, task: it) } }
  let(:webmention) { create(:webmention) }

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def everything = { tasks: [task.id], messages: [message.id], webmentions: [webmention.id] }

  def inbox_ids = API::Slice["repos.inbox_queries"].unseen.map { it.record.id }

  def snooze(**body)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    post "/api/v1/inbox/snooze/all", JSON.generate(body), headers.merge("HTTP_AUTHORIZATION" => "Bearer #{api_token}")
    JSON.parse(last_response.body)
  end

  def status = last_response.status

  it "snoozes every row it names until the time", :aggregate_failures do
    reply = snooze(**everything, snoozed_until: ends_at.iso8601)

    expect([reply, status]).to eq([{ **everything, snoozed_until: ends_at.utc.iso8601 }.transform_keys(&:to_s), 200])
    expect(inbox_ids).to be_empty
  end

  it "leaves a row it was not given in the inbox" do
    later = create(:message, subject: "Later")
    snooze(**everything, snoozed_until: ends_at.iso8601)

    expect(inbox_ids).to eq([later.id])
  end

  it "changes nothing when one row is gone and names it under its kind", :aggregate_failures do
    answer = snooze(**everything, messages: [message.id, 999_999], snoozed_until: ends_at.iso8601)

    expect([answer.fetch("errors"), status]).to eq([{ "messages" => ["no message has the ID 999999"] }, 422])
    expect(inbox_ids).to contain_exactly(task.id, message.id, webmention.id)
  end

  it "refuses a time in the past" do
    answer = snooze(**everything, snoozed_until: (Time.now - 60).iso8601)

    expect([answer.fetch("errors"),
            status]).to eq([{ "snoozed_until" => ["snoozed_until must be in the future"] }, 422])
  end

  it "refuses a call with no rows" do
    answer = snooze(tasks: [], snoozed_until: ends_at.iso8601)

    expect([answer.fetch("errors"), status]).to eq([{ "input" => ["name at least one row to snooze"] }, 422])
  end

  it "answers the MCP tool with the same JSON" do
    reply = trusted(mcp_answer("snooze_inbox", messages: [message.id], snoozed_until: ends_at.iso8601))

    expect(reply).to eq("tasks" => [], "messages" => [message.id], "webmentions" => [],
                        "snoozed_until" => ends_at.utc.iso8601)
  end
end

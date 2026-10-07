# frozen_string_literal: true

RSpec.describe "API inbox wake", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def inbox
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/inbox", {}, headers
    JSON.parse(last_response.body).fetch("inbox")
  end

  def snooze(kind, record)
    slice = { message: Contact::Slice, webmention: Social::Slice, task: Tasks::Slice }.fetch(kind)
    slice["operations.snooze_#{kind}s"].call([record.id], Time.now + 3600)
  end

  def snoozed_message = create(:message, body: "Hi", reply_to: "a@example.com").tap { snooze(:message, it) }

  def status = last_response.status

  def synced(title) = create(:task, title:, list: "external").tap { create(:task_source, task: it) }

  def wake(**body)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    post "/api/v1/inbox/wake", JSON.generate(body), headers
    JSON.parse(last_response.body)
  end

  def woken(kind, title)
    {
      message: -> { create(:message, subject: title, received_at: Time.now - 600) },
      webmention: -> { create(:webmention, author_name: title, received_at: Time.now - 600) },
      task: -> { synced(title) },
    }.fetch(kind).call.tap { snooze(kind, it) }
  end

  %i[message webmention task].each do |kind|
    it "wakes a #{kind} to the top of the inbox and answers with its row", :aggregate_failures do
      create(:message, subject: "Newer")
      record = woken(kind, "Woken")

      reply = wake(kind: kind.to_s, id: record.id)

      expect([status, reply.values_at("kind", "id", "title")]).to eq([200, [kind.to_s, record.id, "Woken"]])
      expect(inbox.first).to eq(reply)
    end
  end

  it "answers a row that is not snoozed with a 422" do
    message = create(:message)

    expect([wake(kind: "message", id: message.id), status])
      .to eq([{ "error" => "invalid", "message" => "message #{message.id} is not snoozed",
                "errors" => { "id" => ["message #{message.id} is not snoozed"] } }, 422])
  end

  it "answers a row that isn't there with a 404" do
    expect([wake(kind: "task", id: 1),
            status]).to eq([{ "error" => "not_found", "message" => "no task has the ID 1" }, 404])
  end

  it "refuses an unknown kind" do
    wake(kind: "comet", id: 1)

    expect(status).to eq(422)
  end

  it "answers the MCP tool with the same JSON once its marks come off" do
    first, second = Array.new(2) { snoozed_message }
    reply = wake(kind: "message", id: first.id)
    tool = trusted(mcp_answer("wake_inbox_row", kind: "message", id: second.id))

    expect(tool.except("id", "at", "title")).to eq(reply.except("id", "at", "title"))
  end

  it "refuses in the tool with the message the endpoint gives" do
    message = create(:message)
    refused = mcp_call("wake_inbox_row", kind: "message", id: message.id)

    expect([refused.fetch("isError"), refused.dig("content", 0, "text")])
      .to eq([true, wake(kind: "message", id: message.id).fetch("message")])
  end
end

# frozen_string_literal: true

RSpec.describe "API clear inbox", type: :request do
  let(:message) { create(:message) }
  let(:task) { synced }
  let(:webmention) { create(:webmention) }

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def clear(**ids)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    post "/api/v1/inbox/seen", JSON.generate(ids), headers.merge("HTTP_AUTHORIZATION" => "Bearer #{api_token}")
    JSON.parse(last_response.body)
  end

  def everything = { tasks: [task.id], messages: [message.id], webmentions: [webmention.id] }

  def marks = [task_unseen?, Contact::Slice["repos.message_queries"].by_id(message.id).status, webmention_marks]

  def status = last_response.status

  def synced = create(:task, :external).tap { create(:task_source, task: it) }

  def task_unseen? = Tasks::Slice["repos.task_repo"].by_id(task.id).source.seen_at.nil?

  def webmention_marks
    Social::Slice["repos.webmention_repo"].by_id(webmention.id).then { [it.seen_at.nil?, it.status] }
  end

  it "marks issues seen, messages read and webmentions seen but pending", :aggregate_failures do
    expect([clear(**everything), status]).to eq([everything.transform_keys(&:to_s), 200])
    expect(marks).to eq([false, "read", [false, "pending"]])
  end

  it "leaves a row it was not given in the inbox" do
    later = create(:message, subject: "Later")
    clear(**everything)

    expect(API::Slice["queries.inbox"].call.map { it.record.id }).to eq([later.id])
  end

  it "changes nothing when one row is gone and names it under its kind", :aggregate_failures do
    gone = create(:webmention).id.tap { Social::Slice["db.rom"].relations[:webmentions].by_pk(it).delete }
    answer = clear(**everything, webmentions: [webmention.id, gone])

    expect([answer.fetch("errors"), status]).to eq([{ "webmentions" => ["no webmention has the ID #{gone}"] }, 422])
    expect(marks).to eq([true, "unread", [true, "pending"]])
  end

  it "refuses a call with no rows" do
    expect([clear(tasks: []).fetch("errors"), status]).to eq([{ "input" => ["name at least one row to clear"] }, 422])
  end

  it "answers the MCP tool with the same JSON" do
    expect(mcp_answer("clear_inbox", messages: [message.id])).to eq({ "tasks" => [], "messages" => [message.id],
                                                                      "webmentions" => [] })
  end
end

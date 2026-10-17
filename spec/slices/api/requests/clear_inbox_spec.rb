# frozen_string_literal: true

RSpec.describe "API clear inbox", type: :request do
  let(:message) { create(:message) }
  let(:task) { synced }
  let(:webmention) { create(:webmention) }

  def clear(**ids)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    post "/api/v1/inbox/seen", JSON.generate(ids), headers.merge("HTTP_AUTHORIZATION" => "Bearer #{api_token}")
    JSON.parse(last_response.body)
  end

  def everything = { tasks: [task.id], messages: [message.id], webmentions: [webmention.id] }

  def gmail_thread
    work = create(:mail_account, address: "aaron@work.example")
    connect_google(account_id: work.address, scopes: Spec::GoogleAccounts::GMAIL_SCOPES)
    create(:message, mail_account_id: work.id, gmail_id: "t1")
  end

  def gmail_transactions
    db = Mail::Slice["db.rom"].gateways[:default].connection
    [].tap do |open|
      stub_request(:post, "#{Spec::GoogleAccounts::GMAIL}/threads/t1/modify")
        .to_return { open << db.in_transaction? and google_health_json({}) }
    end
  end

  def marks = [task_unseen?, Mail::Slice["repos.message_queries"].by_id(message.id).status, webmention_marks]

  def status = last_response.status

  def synced = create(:task, :external).tap { create(:task_source, task: it) }

  def task_unseen? = Tasks::Slice["repos.task_queries"].by_id(task.id).source.seen_at.nil?

  def webmention_marks
    Social::Slice["repos.webmention_queries"].by_id(webmention.id).then { [it.seen_at.nil?, it.status] }
  end

  it "marks issues seen, messages read and webmentions seen but pending", :aggregate_failures do
    expect([clear(**everything), status]).to eq([everything.transform_keys(&:to_s), 200])
    expect(marks).to eq([false, "read", [false, "pending"]])
  end

  it "leaves a row it was not given in the inbox" do
    later = create(:message, subject: "Later")
    clear(**everything)

    expect(API::Slice["repos.inbox_queries"].unseen.map { it.record.id }).to eq([later.id])
  end

  it "changes nothing when one row is gone and names it under its kind", :aggregate_failures do
    gone = create(:webmention).id.tap { Social::Slice["db.rom"].relations[:webmentions].by_pk(it).delete }
    answer = clear(**everything, webmentions: [webmention.id, gone])

    expect([answer.fetch("errors"), status]).to eq([{ "webmentions" => ["no webmention has the ID #{gone}"] }, 422])
    expect(marks).to eq([true, "unread", [true, "pending"]])
  end

  it "marks a Gmail thread read with no transaction open", :aggregate_failures, :commits do
    open = gmail_transactions
    clear(tasks: [task.id], messages: [gmail_thread.id])

    expect([status, open]).to eq([200, [false]])
  end

  it "changes nothing when Gmail refuses a thread", :aggregate_failures do
    thread = gmail_thread
    stub_request(:post, "#{Spec::GoogleAccounts::GMAIL}/threads/t1/modify").to_return(status: 500)

    errors = clear(tasks: [task.id], messages: [thread.id]).fetch("errors")

    expect(errors).to eq({ "messages" => ["could not clear message #{thread.id}"] })
    expect(task_unseen?).to be(true)
  end

  it "marks every issue seen in one update without reloading them", :aggregate_failures do
    tasks = [task.id, synced.id]
    queries = counting { clear(tasks:) }

    expect([queries.grep(/UPDATE "task_sources"/).size, queries.grep(/FROM "tasks"/).size]).to eq([1, 0])
    expect(tasks.map { Tasks::Slice["repos.task_queries"].by_id(it).source.seen_at }).to all(be_a(Time))
  end

  it "keeps the first seen time of an issue already seen" do
    at = Time.utc(2026, 1, 2)
    Tasks::Slice["repos.task_source_mutations"].see([task.id], at)
    clear(tasks: [task.id])

    expect(Tasks::Slice["repos.task_queries"].by_id(task.id).source.seen_at).to eq(at)
  end

  it "refuses a call with no rows" do
    expect([clear(tasks: []).fetch("errors"), status]).to eq([{ "input" => ["name at least one row to clear"] }, 422])
  end

  it "answers the MCP tool with the same JSON" do
    expect(mcp_answer("clear_inbox", messages: [message.id])).to eq({ "tasks" => [], "messages" => [message.id],
                                                                      "webmentions" => [] })
  end
end

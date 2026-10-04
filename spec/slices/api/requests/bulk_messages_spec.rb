# frozen_string_literal: true

RSpec.describe "API bulk message actions", type: :request do
  def act(name, ids) = call_api(name, JSON.generate(ids:))

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(name, body, token: api_token)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    post "/api/v1/messages/bulk/#{name}", body, headers
    JSON.parse(last_response.body)
  end

  def failing(id)
    instance_double(Contact::Operations::ActOnMessages, call: Dry::Monads::Failure[:record, id, :unexpected])
  end

  def gone_id = create(:message).id.tap { repo.delete(it) }

  def ids(messages) = messages.map(&:id)

  def refusal(message) = { "error" => "invalid", "message" => message, "errors" => { "ids" => [message] } }

  def repo = Contact::Slice["repos.message_repo"]

  def status = last_response.status

  def status_of(message) = repo.by_id(message.id)&.status

  def whole(message)
    {
      "id" => message.id,
      "subject" => message.subject,
      "body" => message.body,
      "reply_to" => message.reply_to,
      "received_at" => message.received_at.utc.iso8601,
    }
  end

  {
    "read" => %w[unread read],
    "unread" => %w[read unread],
  }.each do |name, (before, after)|
    describe "POST /api/v1/messages/bulk/#{name}" do
      let!(:picked) { Array.new(2) { create(:message, status: before) } }
      let!(:left) { create(:message, status: before) }

      it "marks the messages it names and answers them" do
        answer = act(name, ids(picked))

        expect([answer.fetch("messages").map { it.values_at("id", "status") }, status])
          .to eq([ids(picked).map { [it, after] }, 200])
      end

      it "answers each message whole" do
        message = picked.first

        expect(act(name, [message.id]).fetch("messages").first.except("status")).to eq(whole(message))
      end

      it "leaves the rest alone" do
        act(name, ids(picked))

        expect(status_of(left)).to eq(before)
      end

      it "marks none when one ID is gone and names it" do
        gone = gone_id

        expect([act(name, [*ids(picked), gone]), status, picked.map { status_of(it) }])
          .to eq([refusal("no message has the ID #{gone}"), 422, [before, before]])
      end
    end
  end

  describe "POST /api/v1/messages/bulk/delete" do
    let!(:picked) { [create(:message, subject: "One"), create(:message, subject: "Two")] }
    let!(:left) { create(:message) }

    it "deletes the messages it names and answers them" do
      answer = act("delete", ids(picked))

      expect([answer, picked.map { status_of(it) }]).to eq(
        [{ "messages" => picked.map { { "id" => it.id, "subject" => it.subject, "deleted" => true } } }, [nil, nil]],
      )
    end

    it "leaves the rest alone" do
      act("delete", ids(picked))

      expect(status_of(left)).to eq("unread")
    end

    it "deletes none when one ID is gone" do
      act("delete", [*ids(picked), gone_id])

      expect([status, picked.map { status_of(it) }]).to eq([422, %w[unread unread]])
    end
  end

  describe "the list of IDs" do
    it "acts on a repeated ID once" do
      message = create(:message)

      expect(act("read", [message.id, message.id]).fetch("messages").map { it.fetch("id") }).to eq([message.id])
    end

    it "refuses an empty list" do
      expect([act("read", []).fetch("errors").keys, status]).to eq([%w[ids], 422])
    end

    it "refuses more than 100 IDs" do
      expect([act("read", (1..101).to_a).fetch("errors").keys, status]).to eq([%w[ids], 422])
    end

    it "refuses an ID that is not a number" do
      expect([act("read", ["one"]).fetch("errors").keys, status]).to eq([%w[ids], 422])
    end

    it "refuses a request with no IDs" do
      expect(call_api("read", "{}").fetch("errors")).to eq("ids" => ["ids is missing"])
    end
  end

  it "answers a failure it did not expect with a 500 that names the message" do
    message = create(:message)
    replace_component("contact.operations.act_on_messages", failing(message.id))

    expect([act("read", [message.id]), status])
      .to eq([{ "error" => "failed", "message" => "could not change message #{message.id}" }, 500])
  end

  it "refuses a request with no token" do
    call_api("read", JSON.generate(ids: [1]), token: nil)

    expect(status).to eq(401)
  end

  describe "the MCP tools" do
    it "mark read as mark_messages_read does" do
      message = create(:message)
      endpoint = act("read", [message.id])
      repo.mark(message, "unread")

      expect(mcp_answer("mark_messages_read", ids: [message.id])).to eq(endpoint)
    end

    it "mark unread as mark_messages_unread does" do
      message = create(:message, :read)
      endpoint = act("unread", [message.id])
      repo.mark(message, "read")

      expect(mcp_answer("mark_messages_unread", ids: [message.id])).to eq(endpoint)
    end

    it "delete as delete_messages does" do
      first = create(:message, subject: "same")
      last = create(:message, subject: "same")
      deleted = act("delete", [first.id])

      expect(mcp_answer("delete_messages", ids: [last.id]))
        .to eq("messages" => deleted.fetch("messages").map { it.merge("id" => last.id) })
    end

    it "refuse a gone ID with the message the endpoint gives" do
      gone = gone_id
      refused = act("read", [gone])

      expect(mcp_text("mark_messages_read", ids: [gone])).to eq(refused.fetch("message"))
    end
  end
end

# frozen_string_literal: true

RSpec.describe "API bulk message actions", type: :request do
  def act(name, ids, **fields) = call_api(name, JSON.generate(ids:, **fields))

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(name, body)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    post "/api/v1/messages/bulk/#{name}", body, headers
    JSON.parse(last_response.body)
  end

  def gone_id = create(:message).id.tap { Contact::Slice["repos.message_mutations"].delete(it) }

  def ids(messages) = messages.map(&:id)

  def refusal(message) = { "error" => "invalid", "message" => message, "errors" => { "ids" => [message] } }

  def repo = Contact::Slice["repos.message_queries"]

  def status = last_response.status

  def status_of(message) = repo.by_id(message.id)&.status

  def tag_names(message) = repo.by_id(message.id).tags.map(&:name)

  def tagged(*names) = create(:message).tap { |message| names.each { tagging.add(message.id, it) } }

  def tagging = Contact::Slice["repos.message_tag_mutations"]

  def whole(message)
    {
      "id" => message.id,
      "subject" => message.subject,
      "body" => message.body,
      "reply_to" => message.reply_to,
      "tags" => [],
      "received_at" => message.received_at.utc.iso8601,
      "snoozed_until" => nil,
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

      it "says when a snooze ends" do
        message = create(:message, status: before, snoozed_until: Time.utc(2099, 1, 2, 3))

        expect(act(name, [message.id]).fetch("messages").first.fetch("snoozed_until")).to eq("2099-01-02T03:00:00Z")
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

  describe "POST /api/v1/messages/bulk/tag" do
    let!(:picked) { [tagged("billing"), tagged] }

    it "adds the tag to each message and keeps the ones it had" do
      answer = act("tag", ids(picked), tag: "Urgent")

      expect([answer.fetch("messages").map { it.fetch("tags") }, status]).to eq([[%w[billing urgent], %w[urgent]], 200])
    end

    it "tags a message once when it already carries the tag" do
      act("tag", ids(picked), tag: "billing")

      expect(picked.map { tag_names(it) }).to eq([%w[billing], %w[billing]])
    end

    it "tags none when one ID is gone and names it" do
      gone = gone_id

      expect([act("tag", [*ids(picked), gone], tag: "urgent"), status, picked.map { tag_names(it) }])
        .to eq([refusal("no message has the ID #{gone}"), 422, [%w[billing], []]])
    end

    it "refuses a tag that is not lowercase words" do
      expect([act("tag", ids(picked), tag: "two words").fetch("errors"), status])
        .to eq([{ "tag" => ["a tag is lowercase words"] }, 422])
    end

    it "refuses a blank tag" do
      expect(act("tag", ids(picked), tag: " ").fetch("message")).to eq("tag: name the tag first")
    end

    it "refuses a request with no tag" do
      expect(call_api("tag", JSON.generate(ids: ids(picked))).fetch("errors")).to eq("tag" => ["tag is missing"])
    end
  end

  describe "POST /api/v1/messages/bulk/untag" do
    let!(:picked) { [tagged("billing", "urgent"), tagged("billing")] }

    it "takes the tag off each message" do
      answer = act("untag", ids(picked), tag: "billing")

      expect([answer.fetch("messages").map { it.fetch("tags") }, status]).to eq([[%w[urgent], []], 200])
    end

    it "untags none when one ID is gone" do
      act("untag", [*ids(picked), gone_id], tag: "billing")

      expect([status, picked.map { tag_names(it) }]).to eq([422, [%w[billing urgent], %w[billing]]])
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

  describe "the MCP tools" do
    it "mark read as mark_messages_read does" do
      message = create(:message)
      endpoint = act("read", [message.id])
      Contact::Slice["repos.message_mutations"].mark(message, "unread")

      expect(mcp_answer("mark_messages_read", ids: [message.id])).to eq(endpoint)
    end

    it "mark unread as mark_messages_unread does" do
      message = create(:message, :read)
      endpoint = act("unread", [message.id])
      Contact::Slice["repos.message_mutations"].mark(message, "read")

      expect(mcp_answer("mark_messages_unread", ids: [message.id])).to eq(endpoint)
    end

    it "delete as delete_messages does" do
      first = create(:message, subject: "same")
      last = create(:message, subject: "same")
      deleted = act("delete", [first.id])

      expect(mcp_answer("delete_messages", ids: [last.id]))
        .to eq("messages" => deleted.fetch("messages").map { it.merge("id" => last.id) })
    end

    it "tag as tag_messages does" do
      message = create(:message)
      tagged_answer = act("tag", [message.id], tag: "billing")

      expect(mcp_answer("tag_messages", ids: [message.id], tag: "billing")).to eq(tagged_answer)
    end

    it "untag as untag_messages does" do
      message = tagged("billing", "urgent")
      untagged = act("untag", [message.id], tag: "billing")
      tagging.add(message.id, "billing")

      expect(mcp_answer("untag_messages", ids: [message.id], tag: "billing")).to eq(untagged)
    end

    it "refuse a gone ID with the message the endpoint gives" do
      gone = gone_id
      refused = act("read", [gone])

      expect(mcp_text("mark_messages_read", ids: [gone])).to eq(refused.fetch("message"))
    end
  end
end

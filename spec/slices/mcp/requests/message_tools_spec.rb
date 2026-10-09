# frozen_string_literal: true

RSpec.describe "MCP contact message tools", type: :request do
  def at(day, hour, minute = 0) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour, minute)

  def message_queries = Contact::Slice["repos.message_queries"]

  def today = Blog::TimeZone.today

  def untrusted(text) = { "untrusted" => true, "text" => text }

  describe "list_messages" do
    def listed(from: today - 6, to: today, **)
      mcp_answer("list_messages", from: from.iso8601, to: to.iso8601, **).fetch("messages")
    end

    def listed_ids(**) = mcp_answer("list_messages", **).fetch("messages").map { it.fetch("id") }

    it "lists the messages in the range, newest first" do
      older = create(:message, received_at: at(today - 3, 9))
      newer = create(:message, received_at: at(today - 1, 9))

      expect(listed.map { it.fetch("id") }).to eq([newer.id, older.id])
    end

    it "keeps both edge days whole" do
      late = create(:message, received_at: at(today - 1, 23, 59))
      create(:message, received_at: at(today, 0))
      create(:message, received_at: at(today - 3, 23, 59))

      expect(listed(from: today - 2, to: today - 1).map { it.fetch("id") }).to eq([late.id])
    end

    it "says what the admin list shows" do
      message = create(:message, :read, subject: "Hello", reply_to: "someone@example.com", received_at: at(today, 0, 5))
      shown = { "subject" => untrusted("Hello"), "reply_to" => untrusted("someone@example.com"), "status" => "read" }

      expect(listed.first).to eq(
        "id" => message.id, **shown, "tags" => [], "received_at" => at(today, 0, 5).utc.iso8601, "snoozed_until" => nil,
      )
    end

    it "lists each message's tags in name order" do
      message = create(:message)
      %w[urgent billing].each { Contact::Slice["repos.message_tag_mutations"].add(message.id, it) }

      expect(listed.first.fetch("tags")).to eq(%w[billing urgent])
    end

    it "says when a snooze ends" do
      create(:message, received_at: at(today, 0), snoozed_until: Time.utc(2099, 1, 2, 3))

      expect(listed.first.fetch("snoozed_until")).to eq("2099-01-02T03:00:00Z")
    end

    it "narrows to one status" do
      create(:message, received_at: at(today, 0))
      spam = create(:message, :spam, received_at: at(today, 0))

      expect(listed(status: "spam").map { it.fetch("id") }).to eq([spam.id])
    end

    it "lists every message, newest first, when given no range" do
      older = create(:message, received_at: at(today - 900, 9))
      newer = create(:message, received_at: at(today, 0))

      answer = mcp_answer("list_messages")

      expect([answer.fetch("messages").map { it.fetch("id") }, answer.values_at("from", "to")])
        .to eq([[newer.id, older.id], [nil, nil]])
    end

    it "pages through every message in one status when given no range" do
      kept = 1.upto(3).map { create(:message, :spam, received_at: at(today - 900 - it, 9)) }
      create(:message, received_at: at(today, 0))
      lower_page_size(:mcp, to: 2)

      expect([1, 2].flat_map { listed_ids(status: "spam", page: it) }).to eq(kept.map(&:id))
    end

    it "lists every message up to a day when given only to" do
      kept = create(:message, received_at: at(today - 900, 9))
      create(:message, received_at: at(today, 0))

      expect(listed_ids(to: (today - 1).iso8601)).to eq([kept.id])
    end

    it "counts the messages in the range by status, whatever the status asked for" do
      create(:message, received_at: at(today, 0))
      create(:message, :spam, received_at: at(today - 1, 9))
      create(:message, :spam, received_at: at(today - 30, 9))

      expect(mcp_answer("list_messages", from: (today - 6).iso8601, to: today.iso8601, status: "spam").fetch("counts"))
        .to eq("unread" => 1, "read" => 0, "spam" => 1)
    end

    it "counts every message when given no range" do
      create(:message, :read, received_at: at(today - 900, 9))
      create(:message, :spam)

      expect(mcp_answer("list_messages").fetch("counts")).to eq("unread" => 0, "read" => 1, "spam" => 1)
    end

    it "refuses a status the admin does not have" do
      expect(mcp_text("list_messages", from: today.iso8601, to: today.iso8601, status: "archived"))
        .to include("/status")
    end

    it "refuses a range that runs backwards" do
      expect(mcp_text("list_messages", from: today.iso8601, to: (today - 1).iso8601)).to eq("from comes after to")
    end
  end

  describe "read_message" do
    it "reads one message whole" do
      message = create(:message, subject: "Hi", body: "I liked the post", reply_to: "a@example.com")

      expect(mcp_answer("read_message", id: message.id)).to include(
        "id" => message.id, "subject" => untrusted("Hi"), "body" => untrusted("I liked the post"),
        "reply_to" => untrusted("a@example.com"), "status" => "unread",
      )
    end

    it "keeps the sender's visitor hash back" do
      message = create(:message)

      expect(mcp_answer("read_message", id: message.id).keys)
        .to contain_exactly("id", "subject", "body", "reply_to", "status", "tags", "received_at", "snoozed_until")
    end

    it "says which tags it carries" do
      message = create(:message)
      Contact::Slice["repos.message_tag_mutations"].add(message.id, "billing")

      expect(mcp_answer("read_message", id: message.id).fetch("tags")).to eq(%w[billing])
    end

    it "says when a snooze ends" do
      message = create(:message, snoozed_until: Time.utc(2099, 1, 2, 3))

      expect(mcp_answer("read_message", id: message.id).fetch("snoozed_until")).to eq("2099-01-02T03:00:00Z")
    end

    it "calls an unknown ID an error" do
      expect(mcp_text("read_message", id: 999_999)).to eq("no message has the ID 999999")
    end
  end

  describe "mark_message" do
    it "marks a message read" do
      message = create(:message)
      mcp_call("mark_message", id: message.id, status: "read")

      expect(message_queries.by_id(message.id).status).to eq("read")
    end

    it "marks a message spam and says so" do
      message = create(:message, :read)

      expect(mcp_answer("mark_message", id: message.id, status: "spam")).to eq("id" => message.id, "status" => "spam")
    end

    it "calls an unknown ID an error" do
      expect(mcp_text("mark_message", id: 999_999, status: "read")).to eq("no message has the ID 999999")
    end

    it "refuses a status the admin does not have" do
      message = create(:message)

      expect(mcp_text("mark_message", id: message.id, status: "archived")).to include("/status")
    end

    it "leaves the message alone when it refuses" do
      message = create(:message)
      mcp_call("mark_message", id: message.id, status: "archived")

      expect(message_queries.by_id(message.id).status).to eq("unread")
    end
  end
end

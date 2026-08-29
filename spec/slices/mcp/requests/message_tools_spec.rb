# frozen_string_literal: true

RSpec.describe "MCP contact message tools", type: :request do
  def at(day, hour, minute = 0) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour, minute)

  def message_repo = Contact::Slice["repos.message_repo"]

  def today = Blog::TimeZone.today

  describe "list_messages" do
    def listed(from: today - 6, to: today, **)
      mcp_answer("list_messages", from: from.iso8601, to: to.iso8601, **).fetch("messages")
    end

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
      shown = { "subject" => "Hello", "reply_to" => "someone@example.com", "status" => "read" }

      expect(listed.first).to eq("id" => message.id, **shown, "received_at" => at(today, 0, 5).utc.iso8601)
    end

    it "narrows to one status" do
      create(:message, received_at: at(today, 0))
      spam = create(:message, :spam, received_at: at(today, 0))

      expect(listed(status: "spam").map { it.fetch("id") }).to eq([spam.id])
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
        "id" => message.id, "subject" => "Hi", "body" => "I liked the post", "reply_to" => "a@example.com",
        "status" => "unread",
      )
    end

    it "keeps the sender's visitor hash back" do
      message = create(:message)

      expect(mcp_answer("read_message", id: message.id).keys)
        .to contain_exactly("id", "subject", "body", "reply_to", "status", "received_at")
    end

    it "calls an unknown ID an error" do
      expect(mcp_text("read_message", id: 404)).to eq("no message has the ID 404")
    end
  end

  describe "mark_message" do
    it "marks a message read" do
      message = create(:message)
      mcp_call("mark_message", id: message.id, status: "read")

      expect(message_repo.by_id(message.id).status).to eq("read")
    end

    it "marks a message spam and says so" do
      message = create(:message, :read)

      expect(mcp_answer("mark_message", id: message.id, status: "spam")).to eq("id" => message.id, "status" => "spam")
    end

    it "calls an unknown ID an error" do
      expect(mcp_text("mark_message", id: 404, status: "read")).to eq("no message has the ID 404")
    end

    it "refuses a status the admin does not have" do
      message = create(:message)

      expect(mcp_text("mark_message", id: message.id, status: "archived")).to include("/status")
    end

    it "leaves the message alone when it refuses" do
      message = create(:message)
      mcp_call("mark_message", id: message.id, status: "archived")

      expect(message_repo.by_id(message.id).status).to eq("unread")
    end
  end
end

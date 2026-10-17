# frozen_string_literal: true

RSpec.describe "MCP mail scope", type: :request do
  let!(:thread) { create(:message, subject: "Zeppelin sighting", received_at: Time.now - 600) }

  def ends_at = (Time.now + 3600).utc.iso8601

  def found_kinds(**) = mcp_answer("search", query: "zeppelin", **).fetch("results").map { it.fetch("kind") }

  def inbox_kinds = mcp_answer("list_inbox").fetch("inbox").map { it.fetch("kind") }

  def snooze(record) = Mail::Slice["operations.snooze_messages"].call([record.id], Time.now + 3600)

  def stored = Mail::Slice["repos.message_queries"].by_id(thread.id)

  before { create(:task, title: "Track the zeppelin") }

  describe "a connection without mail" do
    def mcp_scopes = %w[read write delete]

    it "finds no mail in search" do
      expect(found_kinds).to eq(%w[task])
    end

    it "refuses a search for kind message" do
      result = mcp_call("search", query: "zeppelin", kind: "message")

      expect([result.fetch("isError"), result.dig("content", 0, "text")])
        .to eq([true, "message rows need the mail scope"])
    end

    it "finds no mail in activity, its summary or attention" do
      day = { from: Blog::TimeZone.today.iso8601, to: Blog::TimeZone.today.iso8601 }
      answers = [mcp_text("read_activity", **day), mcp_text("summarize_activity", **day), mcp_text("list_attention")]

      expect(answers.join).not_to include("Zeppelin sighting")
    end

    it "lists no mail in the inbox" do
      create(:webmention)

      expect(inbox_kinds).to eq(%w[webmention])
    end

    {
      "clear_inbox" => -> { { messages: [thread.id] } },
      "snooze_inbox" => -> { { messages: [thread.id], snoozed_until: ends_at } },
      "snooze_inbox_row" => -> { { kind: "message", id: thread.id, snoozed_until: ends_at } },
    }.each do |name, arguments|
      it "refuses a message row in #{name} and leaves the thread alone" do
        expect([mcp_text(name, **instance_exec(&arguments)), stored.to_h.slice(:status, :snoozed_until)])
          .to eq(["message rows need the mail scope", { status: "unread", snoozed_until: nil }])
      end
    end

    it "refuses to link a record to a mail thread, naming mail" do
      post = create(:post)

      expect([mcp_text("link_records", kind: "post", id: post.id, other_kind: "mail_thread", other_id: thread.id),
              Links::Slice["relations.record_links"].count])
        .to eq(["this endpoint needs a token with the mail scope", 0])
    end

    it "hides a linked mail thread from list_links" do
      post = create(:post)
      Links::Slice["operations.link_records"].call("post", post.id, { other_kind: "mail_thread", other_id: thread.id })

      expect(mcp_answer("list_links", kind: "post", id: post.id).fetch("links")).to eq({})
    end

    it "refuses to wake a message row" do
      snooze(thread)

      expect([mcp_text("wake_inbox_row", kind: "message", id: thread.id), stored.snoozed_until])
        .to match(["message rows need the mail scope", be > Time.now])
    end
  end

  describe "a connection with mail" do
    def mcp_scopes = %w[read write mail]

    it "finds mail in search" do
      expect(found_kinds).to contain_exactly("task", "message")
    end

    it "lists mail in the inbox" do
      expect(inbox_kinds).to eq(%w[message])
    end

    it "links a record to a mail thread, marking the subject untrusted" do
      post = create(:post)

      expect(mcp_answer("link_records", kind: "post", id: post.id, other_kind: "mail_thread", other_id: thread.id)
        .dig("links", "mail_thread").map { it.fetch("title") })
        .to eq([marked("Zeppelin sighting")])
    end

    it "unlinks a record from a mail thread" do
      post = create(:post)
      Links::Slice["operations.link_records"].call("post", post.id, { other_kind: "mail_thread", other_id: thread.id })
      mcp_call("unlink_records", kind: "mail_thread", id: thread.id, other_kind: "post", other_id: post.id)

      expect(Links::Slice["relations.record_links"].count).to eq(0)
    end

    it "clears a message row" do
      mcp_call("clear_inbox", messages: [thread.id])

      expect(stored.status).to eq("read")
    end
  end
end

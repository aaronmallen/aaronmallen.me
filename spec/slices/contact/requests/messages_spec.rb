# frozen_string_literal: true

RSpec.describe "Contact messages", type: :request do
  let(:fields) { { reply_to: "ada@example.com", subject: "A question", body: "About the beacon" } }
  let(:limit) { Hanami.app["settings"].contact[:throttle_limit] }
  let(:message_repo) { Contact::Slice["repos.message_repo"] }
  let(:sender) { Analytics::Slice["operations.hash_visitor"].call(address: "127.0.0.1") }

  def crlf_lines = Array.new(Contact::MessageLimits::MAX_BODY / 10) { "a" * 9 }.join("\r\n")

  def send_message(**changes) = post("/contact", message: fields.merge(changes))

  def stored = message_repo.by_status(Blog::Types::MessageStatus["unread"])

  describe "a message" do
    it "is stored with the ends of every field trimmed" do
      send_message(reply_to: " ada@example.com ", subject: "  A question ", body: "\n About the beacon \n")

      expect(stored.first).to have_attributes(**fields)
    end

    it "is stored with a subject at the cap" do
      send_message(subject: "a" * Contact::MessageLimits::MAX_SUBJECT)

      expect(last_response.status).to eq(302)
    end

    it "is stored with a body at the cap" do
      send_message(body: "a" * Contact::MessageLimits::MAX_BODY)

      expect(last_response.status).to eq(302)
    end

    it "is stored with a body at the cap as the counter counts it, with the browser's line breaks" do
      send_message(body: "#{crlf_lines}a")

      expect(last_response.status).to eq(302)
    end

    it "is refused with a body over the cap once its line breaks fold" do
      send_message(body: "#{crlf_lines}aa")

      expect(last_response.status).to eq(422)
    end

    it "is stored with every line break in the body as a newline" do
      send_message(body: "About\r\nthe\rbeacon\n")

      expect(stored.first.body).to eq("About\nthe\nbeacon")
    end

    it "is refused with a subject over the cap" do
      send_message(subject: "a" * (Contact::MessageLimits::MAX_SUBJECT + 1))

      expect(last_response.status).to eq(422)
    end

    it "is refused with a reply address over the cap" do
      send_message(reply_to: "#{'a' * Contact::MessageLimits::MAX_REPLY_TO}@example.com")

      expect(last_response.status).to eq(422)
    end
  end

  describe "a sender whose messages all went out before the window opened" do
    before do
      window = Hanami.app["settings"].contact[:throttle_window_minutes] * 60
      limit.times { create(:message, visitor_hash: sender, received_at: Time.now - window - 60) }
      send_message
    end

    it "is heard again" do
      expect(last_response.status).to eq(302)
    end

    it "gets the message stored" do
      expect(message_repo.messages.count).to eq(limit + 1)
    end
  end

  describe "a sender marked as spam" do
    def admin_mark(message, status)
      sign_in_to_admin
      post("/admin/messages/#{message.id}/mark/#{status}", _csrf_token: admin_csrf_token)
    end

    def arrived = message_repo.messages.order(:id).to_a.last

    def mcp_mark(message, status) = mcp_call("mark_message", id: message.id, status:)

    def reap_after(days)
      later = Time.now + (days * 24 * 60 * 60)
      allow(Time).to receive(:now).and_return(later)
      Contact::Jobs::ReapSpamMessages.new.perform
    end

    it "files their next message as spam when the admin marked them" do
      admin_mark(create(:message, reply_to: "ada@example.com"), "spam")
      send_message

      expect(arrived.status).to eq("spam")
    end

    it "files their next message as spam when MCP marked them" do
      mcp_mark(create(:message, reply_to: "ada@example.com"), "spam")
      send_message

      expect(arrived.status).to eq("spam")
    end

    it "matches the address in any letter case" do
      mcp_mark(create(:message, reply_to: "Ada@Example.COM"), "spam")
      send_message(reply_to: "aDA@example.com")

      expect(arrived.status).to eq("spam")
    end

    it "tells the sender the same as anyone else" do
      mcp_mark(create(:message, reply_to: "ada@example.com"), "spam")
      send_message

      expect(last_response.status).to eq(302)
    end

    it "files a message from another address as unread" do
      mcp_mark(create(:message, reply_to: "ada@example.com"), "spam")
      send_message(reply_to: "grace@example.com")

      expect(arrived.status).to eq("unread")
    end

    it "lets the reaper delete their next message in time" do
      mcp_mark(create(:message, reply_to: "ada@example.com"), "spam")
      send_message

      expect { reap_after(31) }.to change { message_repo.messages.count }.from(2).to(0)
    end

    it "files their next message as spam after the reaper deletes the one that marked them" do
      mcp_mark(create(:message, reply_to: "ada@example.com"), "spam")
      reap_after(31)
      send_message

      expect(arrived.status).to eq("spam")
    end

    { "read" => :mcp_mark, "unread" => :admin_mark }.each do |status, marker|
      it "files their next message as unread once a message from them is marked #{status}" do
        mcp_mark(create(:message, reply_to: "ada@example.com"), "spam")
        send_message
        send(marker, arrived, status)
        send_message

        expect(arrived.status).to eq("unread")
      end
    end

    context "with the total limit reached by their messages" do
      before do
        settings = Hanami.app["settings"]
        allow(settings).to receive(:contact).and_return(settings.contact.merge(total_throttle_limit: 2))
        mcp_mark(create(:message, reply_to: "ada@example.com"), "spam")
        send_message
        send_message(reply_to: "grace@example.com")
      end

      it "refuses the next sender, since spam counts toward the total", :aggregate_failures do
        expect(last_response.status).to eq(429)
        expect(message_repo.messages.count).to eq(2)
      end
    end

    it "files their next message as spam when a neighbour is marked read" do
      mcp_mark(create(:message, reply_to: "ada@example.com"), "spam")
      mcp_mark(create(:message, reply_to: "grace@example.com"), "read")
      send_message

      expect(arrived.status).to eq("spam")
    end
  end

  shared_context "with two messages held at the lock" do
    def database = Contact::Slice["db.rom"].gateways[:default].connection

    def held_by_another_session
      other = Sequel.connect(database.opts.merge(max_connections: 1))
      other.get(Sequel.function(:pg_advisory_lock, Sequel.function(:hashtext, "messages")))
      yield
    ensure
      other&.disconnect
    end

    def send_in_thread(address)
      Thread.new do
        Rack::MockRequest.new(app).post("/contact", params: { message: fields }, "REMOTE_ADDR" => address)
      end
    end

    def sent_together(addresses)
      senders = held_by_another_session do
        addresses.map { send_in_thread(it) }.tap { wait_until_both_wait }
      end
      senders.map { it.value.status }
    end

    def wait_until_both_wait
      here = database[:pg_database].where(datname: Sequel.function(:current_database)).select(:oid)
      waiting = database[:pg_locks].where(locktype: "advisory", granted: false, database: here)
      Timeout.timeout(5) { sleep(0.01) until waiting.count == 2 }
    end
  end

  describe "two messages from one sender that both pass the count before the lock", :commits do
    include_context "with two messages held at the lock"

    before { lower_throttle_limit(:contact, to: 1) }

    it "takes one and refuses the other" do
      expect(sent_together(%w[127.0.0.1 127.0.0.1]).tally).to eq(302 => 1, 429 => 1)
    end

    it "stores only the one it took" do
      sent_together(%w[127.0.0.1 127.0.0.1])

      expect(message_repo.messages.count).to eq(1)
    end
  end

  describe "two messages from two senders that both pass the total count before the lock", :commits do
    include_context "with two messages held at the lock"

    before do
      settings = Hanami.app["settings"]
      allow(settings).to receive(:contact).and_return(settings.contact.merge(total_throttle_limit: 1))
    end

    it "takes one and refuses the other" do
      expect(sent_together(%w[203.0.113.7 198.51.100.4]).tally).to eq(302 => 1, 429 => 1)
    end

    it "stores only the one it took" do
      sent_together(%w[203.0.113.7 198.51.100.4])

      expect(message_repo.messages.count).to eq(1)
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Contact messages", type: :request do
  let(:fields) { { reply_to: "ada@example.com", subject: "A question", body: "About the beacon" } }
  let(:limit) { Hanami.app["settings"].contact[:throttle_limit] }
  let(:message_repo) { Contact::Slice["repos.message_repo"] }
  let(:sender) { Analytics::Slice["operations.hash_visitor"].call(address: "127.0.0.1") }

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

  describe "two messages from one sender that both pass the count before the lock", :commits do
    def database = Contact::Slice["db.rom"].gateways[:default].connection

    def held_by_another_session
      other = Sequel.connect(database.opts.merge(max_connections: 1))
      other.get(Sequel.function(:pg_advisory_lock, Sequel.function(:hashtext, "messages"),
                                Sequel.function(:hashtext, sender)))
      yield
    ensure
      other&.disconnect
    end

    def send_in_thread
      Thread.new do
        Rack::MockRequest.new(app).post("/contact", params: { message: fields }, "REMOTE_ADDR" => "127.0.0.1")
      end
    end

    def sent_together
      senders = held_by_another_session do
        Array.new(2) { send_in_thread }.tap { wait_until_both_wait }
      end
      senders.map { it.value.status }
    end

    def wait_until_both_wait
      here = database[:pg_database].where(datname: Sequel.function(:current_database)).select(:oid)
      waiting = database[:pg_locks].where(locktype: "advisory", granted: false, database: here)
      Timeout.timeout(5) { sleep(0.01) until waiting.count == 2 }
    end

    before { lower_throttle_limit(:contact, to: 1) }

    it "takes one and refuses the other" do
      expect(sent_together.tally).to eq(302 => 1, 429 => 1)
    end

    it "stores only the one it took" do
      sent_together

      expect(message_repo.messages.count).to eq(1)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Blog::DB::Relation do
  let(:connection) { Social::Slice["db.rom"].gateways.fetch(:default).connection }
  let(:elsewhere) { Sequel.connect(connection.opts) }

  after { elsewhere.disconnect }

  def free_elsewhere?(*keys) = elsewhere.get(Sequel.function(:pg_try_advisory_lock, *keys))

  def hashtext(text) = Sequel.function(:hashtext, text)

  def relation(slice, name) = slice["db.rom"].relations[name]

  describe "#lock_until_commit" do
    let(:events) { relation(Analytics::Slice, :analytics_events) }
    let(:receipts) { relation(Social::Slice, :webmention_receipts) }

    def free_while_locked?(locked, *keys, elsewhere:)
      locked.transaction do
        locked.lock_until_commit(*keys)
        free_elsewhere?(*elsewhere)
      end
    end

    it "locks on its own table name" do
      expect(free_while_locked?(receipts, elsewhere: [hashtext("webmention_receipts")])).to be(false)
    end

    it "locks on its table name and an extra key" do
      sender = hashtext("sender")

      expect(free_while_locked?(events, sender, elsewhere: [hashtext("analytics_events"), sender])).to be(false)
    end

    it "leaves another table's lock free" do
      expect(free_while_locked?(receipts, elsewhere: [hashtext("messages")])).to be(true)
    end
  end

  describe "#with_advisory_lock" do
    let(:states) { relation(Record::Slice, :sync_states) }

    it "runs the block when the lock is free" do
      expect(states.with_advisory_lock(7_000_585) { :ran }).to eq(:ran)
    end

    it "hands back busy when another session holds the lock" do
      free_elsewhere?(7_000_585)

      expect(states.with_advisory_lock(7_000_585, busy: :busy) { :ran }).to eq(:busy)
    end

    it "lets the lock go after the block" do
      states.with_advisory_lock(7_000_585) { :ran }

      expect(free_elsewhere?(7_000_585)).to be(true)
    end
  end
end

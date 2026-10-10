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

  describe "#tally" do
    let(:decisions) { relation(Decisions::Slice, :decisions) }

    before do
      create(:decision, status: "open")
      create(:decision, status: "open")
      create(:decision, status: "dropped")
    end

    it "counts rows by a column" do
      expect(decisions.tally(:status)).to eq("open" => 2, "dropped" => 1)
    end

    it "fills the values it is given with zero" do
      expect(decisions.tally(:status, %w[open resolved dropped])).to eq("open" => 2, "resolved" => 0, "dropped" => 1)
    end
  end

  describe "#with_advisory_lock" do
    let(:states) { relation(Record::Slice, :sync_states) }

    it "runs the block when the lock is free" do
      expect(states.with_advisory_lock("relation spec") { :ran }).to eq(:ran)
    end

    it "locks on the hash of its name" do
      held = states.with_advisory_lock("relation spec") { free_elsewhere?(hashtext("relation spec")) }

      expect(held).to be(false)
    end

    it "fails with lock_busy when another session holds the lock" do
      free_elsewhere?(hashtext("relation spec"))

      expect(states.with_advisory_lock("relation spec") { :ran }).to eq(Dry::Monads::Failure(:lock_busy))
    end

    it "hands back busy when given one" do
      free_elsewhere?(hashtext("relation spec"))

      expect(states.with_advisory_lock("relation spec", busy: :busy) { :ran }).to eq(:busy)
    end

    it "leaves another name's lock free" do
      expect(states.with_advisory_lock("relation spec") { free_elsewhere?(hashtext("other spec")) }).to be(true)
    end

    it "lets the lock go after the block" do
      states.with_advisory_lock("relation spec") { :ran }

      expect(free_elsewhere?(hashtext("relation spec"))).to be(true)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Tasks::Operations::CaptureTask, :commits, :frozen_clock do
  let(:client) { Spec::IssueClient.new }

  def capture(title) = Tasks::Slice["operations.capture_task"].call({ title:, note: "", tags: "" })

  def database = Tasks::Slice["db.rom"].gateways[:default].connection

  def held_by_another_session
    other = Sequel.connect(database.opts.merge(max_connections: 1))
    other.get(Sequel.function(:pg_advisory_lock, Sequel.function(:hashtext, "tasks")))
    yield
  ensure
    other&.disconnect
  end

  def import(id)
    url = "https://linear.app/acme/issue/#{id}"
    client.assigned << { body: "", id:, reference: id, remote_state: "open", title: id, url: }
    Tasks::Slice["operations.sync_issues"].call(provider: "linear", client:)
  end

  def placed_together(*writes)
    held_by_another_session do
      writes.map { Thread.new(&it) }.tap { wait_until_all_wait(writes.size) }
    end.each(&:join)
    Tasks::Slice["relations.tasks"].pluck(:position)
  end

  def wait_until_all_wait(count)
    here = database[:pg_database].where(datname: Sequel.function(:current_database)).select(:oid)
    waiting = database[:pg_locks].where(locktype: "advisory", granted: false, database: here)
    Timeout.timeout(5) { sleep(0.01) until waiting.count == count }
  end

  describe "two tasks placed at once" do
    it "gives two captured tasks different positions" do
      positions = placed_together(-> { capture("one") }, -> { capture("two") })

      expect(positions.uniq.size).to eq(2)
    end

    it "gives a captured task and an imported one different positions" do
      positions = placed_together(-> { capture("one") }, -> { import("L_two") })

      expect(positions.uniq.size).to eq(2)
    end
  end
end

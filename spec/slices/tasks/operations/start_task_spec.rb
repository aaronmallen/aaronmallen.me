# frozen_string_literal: true

RSpec.describe Tasks::Operations::StartTask do
  describe "two starts of one task at once", :commits do
    def database = Tasks::Slice["db.rom"].gateways[:default].connection

    def held(task)
      other = Sequel.connect(database.opts.merge(max_connections: 1))
      other.transaction do
        other[:tasks].where(id: task.id).for_update.first
        yield
      end
    ensure
      other&.disconnect
    end

    def open_sessions(task) = Tasks::Slice["relations.work_sessions"].for_task(task.id).where(ended_at: nil).to_a

    def started_together(task)
      held(task) do
        Array.new(2) { Thread.new { Tasks::Slice["operations.start_task"].call(task.id) } }.tap { wait_until_waiting(2) }
      end.map(&:value)
    end

    def wait_until_waiting(count)
      waiting = database[:pg_stat_activity].where(datname: Sequel.function(:current_database), wait_event_type: "Lock")
      Timeout.timeout(5) { sleep(0.01) until waiting.count == count }
    end

    it "lets both succeed and leaves one open session", :aggregate_failures do
      task = create(:task)
      results = started_together(task)

      expect(results).to all(be_success)
      expect(open_sessions(task).size).to eq(1)
    end
  end
end

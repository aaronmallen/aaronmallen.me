# frozen_string_literal: true

RSpec.describe Tasks::Operations::DeleteWorkSession do
  describe "two deletes of one session at once", :commits do
    let(:started) { Time.at(((Time.now.to_i - 86_400) / 60) * 60) }
    let(:task) { create(:task, worked_seconds: 3600) }
    let!(:session) { create(:work_session, task_id: task.id, started_at: started, ended_at: started + 1800) }

    def database = Tasks::Slice["db.rom"].gateways[:default].connection

    def deleted_together
      held do
        Array.new(2) { Thread.new { described_class.new.call(task.id, session.id) } }.tap { wait_until_waiting(2) }
      end.map(&:value)
    end

    def held
      other = Sequel.connect(database.opts.merge(max_connections: 1))
      other.transaction do
        other[:tasks].where(id: task.id).for_update.first
        yield
      end
    ensure
      other&.disconnect
    end

    def wait_until_waiting(count)
      waiting = database[:pg_stat_activity].where(datname: Sequel.function(:current_database), wait_event_type: "Lock")
      Timeout.timeout(5) { sleep(0.01) until waiting.count == count }
    end

    it "takes the session's length off the total once" do
      deleted_together

      expect(Tasks::Slice["repos.task_queries"].by_id(task.id).worked_seconds).to eq(1800)
    end

    it "answers the second delete with not found" do
      expect(deleted_together.map { it.failure? ? it.failure : :deleted }).to contain_exactly(:deleted, :not_found)
    end
  end
end

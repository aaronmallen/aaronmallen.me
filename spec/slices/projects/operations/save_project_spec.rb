# frozen_string_literal: true

RSpec.describe Projects::Operations::SaveProject do
  let(:repo) { Projects::Slice["repos.project_repo"] }

  def save(name) = Projects::Slice["operations.save_project"].call({ name:, tags: "" })

  describe "two projects saved at once", :commits do
    def database = Projects::Slice["db.rom"].gateways[:default].connection

    def held_by_another_session
      other = Sequel.connect(database.opts.merge(max_connections: 1))
      other.get(Sequel.function(:pg_advisory_lock, Sequel.function(:hashtext, "projects")))
      yield
    ensure
      other&.disconnect
    end

    def saved_together(*names)
      held_by_another_session do
        names.map { |name| Thread.new { save(name) } }.tap { wait_until_all_wait(names.size) }
      end.map(&:value)
    end

    def wait_until_all_wait(count)
      here = database[:pg_database].where(datname: Sequel.function(:current_database)).select(:oid)
      waiting = database[:pg_locks].where(locktype: "advisory", granted: false, database: here)
      Timeout.timeout(5) { sleep(0.01) until waiting.count == count }
    end

    it "saves both", :aggregate_failures do
      results = saved_together("one", "two")

      expect(results).to all(be_success)
      expect(repo.live.map(&:position).uniq.size).to eq(2)
    end
  end
end

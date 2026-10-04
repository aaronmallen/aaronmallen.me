# frozen_string_literal: true

require "fugit"

RSpec.describe Tasks::Jobs::RollOverSprint, :frozen_clock do
  subject(:job) { described_class.new }

  let(:sprint_repo) { Tasks::Slice["repos.sprint_repo"] }
  let(:task_repo) { Tasks::Slice["repos.task_repo"] }
  let(:today) { Blog::TimeZone.today }
  let(:yesterday) { create(:sprint, sprint_date: today - 1) }

  it "starts the day's sprint" do
    job.perform

    expect(sprint_repo.on(today).sprint_date).to eq(today)
  end

  it "carries an unfinished task into it" do
    task = create(:task, :in_sprint, sprint_id: yesterday.id)
    job.perform

    expect(task_repo.by_id(task.id).sprint_id).to eq(sprint_repo.on(today).id)
  end

  it "leaves a finished task in the sprint it was finished in" do
    task = create(:task, :done, :in_sprint, sprint_id: yesterday.id)
    job.perform

    expect(task_repo.by_id(task.id).sprint_id).to eq(yesterday.id)
  end

  it "leaves a canceled task in the sprint it was canceled in" do
    task = create(:task, :canceled, :in_sprint, sprint_id: yesterday.id)
    job.perform

    expect(task_repo.by_id(task.id).sprint_id).to eq(yesterday.id)
  end

  it "counts no arrival for a canceled task" do
    create(:task, :canceled, :in_sprint, sprint_id: yesterday.id)
    job.perform

    expect(sprint_repo.on(today).carried_in).to eq(0)
  end

  it "starts one sprint when it runs twice" do
    2.times { job.perform }

    expect(sprint_repo.sprints.on(today).count).to eq(1)
  end

  it "raises when the roll fails, so the failure reaches the logs" do
    create(:task, :in_sprint, sprint_id: yesterday.id)
    allow(sprint_repo).to receive(:by_id).and_return(nil)
    current_sprint = Tasks::Operations::CurrentSprint.new(sprint_repo:)

    expect { described_class.new(current_sprint:).perform }.to raise_error(described_class::RollOverFailed, "not_found")
  end

  describe "two roll-overs at once", :commits do
    let(:carried) { create(:task, :in_progress, :in_sprint, sprint_id: yesterday.id) }

    def database = Tasks::Slice["db.rom"].gateways[:default].connection

    def held_by_another_session
      other = Sequel.connect(database.opts.merge(max_connections: 1))
      other.get(Sequel.function(:pg_advisory_lock, Sequel.function(:hashtext, "sprints")))
      yield
    ensure
      other&.disconnect
    end

    def rolled_together
      create(:sprint, sprint_date: today)
      create(:work_session, task_id: carried.id, started_at: Time.now - 60)
      held_by_another_session do
        Array.new(2) { Thread.new { Tasks::Operations::CurrentSprint.new.call } }.tap { wait_until_all_wait(2) }
      end.map(&:value)
    end

    def wait_until_all_wait(count)
      here = database[:pg_database].where(datname: Sequel.function(:current_database)).select(:oid)
      waiting = database[:pg_locks].where(locktype: "advisory", granted: false, database: here)
      Timeout.timeout(5) { sleep(0.01) until waiting.count == count }
    end

    it "lets both succeed" do
      expect(rolled_together).to all(be_success)
    end

    it "records one move for the carried task" do
      rolled_together
      moves = Tasks::Slice["relations.task_events"].for_task(carried.id).where(kind: "moved")

      expect(moves.count).to eq(1)
    end
  end

  describe "the schedule" do
    let(:entry) { sidekiq_schedule("roll_over_sprint") }

    it "names the job" do
      expect(Object.const_get(entry.fetch("class"))).to eq(described_class)
    end

    it "runs the job every day" do
      cron = Fugit::Cron.parse(entry.fetch("cron"))
      first = cron.next_time(Time.utc(2026, 9, 17, 12))

      expect(cron.next_time(first).to_t - first.to_t).to eq(24 * 60 * 60)
    end

    it "runs the job as the Chicago day turns, not the UTC one" do
      cron = Fugit::Cron.parse(entry.fetch("cron"))
      run = cron.next_time(Time.utc(2026, 9, 17, 12)).to_t

      expect(Blog::TimeZone.local(run).iso8601).to eq("2026-09-18T00:00:00-05:00")
    end
  end
end

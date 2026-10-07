# frozen_string_literal: true

RSpec.describe Tasks::Jobs::RollOverSprint, :frozen_clock do
  subject(:job) { described_class.new }

  let(:sprint_repo) { Tasks::Slice["repos.sprint_queries"] }
  let(:task_repo) { Tasks::Slice["repos.task_queries"] }
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
    current_sprint = Tasks::Operations::CurrentSprint.new(sprint_queries: sprint_repo)

    expect { described_class.new(current_sprint:).perform }.to raise_error(described_class::RollOverFailed, "not_found")
  end

  describe "a task in progress" do
    let(:now) { Time.at(Time.now.to_i) }

    def running
      task = create(:task, :in_progress, :in_sprint, sprint_id: yesterday.id)
      create(:work_session, task_id: task.id, started_at: now - 5400)
      task
    end

    def spans(task)
      sessions = Tasks::Slice["relations.work_sessions"].for_task(task.id).order(:started_at).to_a
      sessions.map { [it[:started_at], it[:ended_at]] }
    end

    it "ends its session and opens a new one", :aggregate_failures do
      task = running
      job.perform

      expect(spans(task)).to eq([[now - 5400, now], [now, nil]])
      expect(task_repo.by_id(task.id).status).to eq("in_progress")
    end
  end

  describe "the events it records" do
    def events(task) = Tasks::Slice["relations.task_events"].for_task(task.id).in_order.to_a.map(&:to_h)

    it "records the move from yesterday's sprint into today's" do
      task = create(:task, :in_sprint, sprint_id: yesterday.id)
      job.perform

      expect(events(task).map { it.slice(:kind, :from_list, :from_sprint_on, :to_list, :to_sprint_on) })
        .to eq([{ kind: "moved", from_list: nil, from_sprint_on: today - 1, to_list: nil, to_sprint_on: today }])
    end

    it "records no status change for a task it carries in progress" do
      task = create(:task, :in_progress, :in_sprint, sprint_id: yesterday.id)
      job.perform

      expect(events(task).map { it[:kind] }).not_to include("status_changed")
    end

    it "records nothing for a finished task it leaves behind" do
      task = create(:task, :done, :in_sprint, sprint_id: yesterday.id)
      job.perform

      expect(events(task)).to be_empty
    end
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
end

# frozen_string_literal: true

RSpec.describe "Work sessions", type: :request do
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:today) { Blog::TimeZone.today }
  let(:started) { Time.at(Time.now.to_i - 5400) }

  def open_sessions(task) = sessions(task).select { it[:ended_at].nil? }

  def operation(name) = Tasks::Slice["operations.#{name}"]

  def running(*traits, sprint: create(:sprint, sprint_date: today))
    task = create(:task, :in_progress, :in_sprint, *traits, sprint_id: sprint.id)
    create(:work_session, task_id: task.id, started_at: started)
    task
  end

  def send_to(path, **params)
    post path, { _csrf_token: admin_csrf_token, **params }
  end

  def sessions(task) = Tasks::Slice["relations.work_sessions"].for_task(task.id).order(:started_at).to_a

  before { sign_in_to_admin }

  describe "starting a task" do
    it "opens a session at that moment" do
      task = create(:task)
      operation(:start_task).call(task.id, at: started)

      expect(sessions(task).map { [it[:started_at], it[:ended_at]] }).to eq([[started, nil]])
    end

    it "opens no second session for a task already in progress" do
      task = running
      operation(:start_task).call(task.id)

      expect(sessions(task).size).to eq(1)
    end

    it "keeps the session whole while the task page loads on the day it started", :aggregate_failures do
      task = create(:task)
      operation(:start_task).call(task.id, at: started)
      2.times { get "/admin/tasks/#{task.id}" }

      expect(last_response.status).to eq(200)
      expect(sessions(task).map { [it[:started_at], it[:ended_at]] }).to eq([[started, nil]])
    end
  end

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

    def started_together(task)
      held(task) do
        Array.new(2) { Thread.new { operation(:start_task).call(task.id) } }.tap { wait_until_waiting(2) }
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

  describe "pausing a task" do
    it "ends the open session" do
      task = running
      send_to("/admin/tasks/#{task.id}/stop")

      expect(sessions(task).first[:ended_at]).to be_within(5).of(Time.now)
    end

    it "opens a new session when the task starts again", :aggregate_failures do
      task = running
      operation(:reopen_task).call(task.id, at: started + 600)
      operation(:start_task).call(task.id, at: started + 1200)

      expect(sessions(task).map { [it[:started_at], it[:ended_at]] })
        .to eq([[started, started + 600], [started + 1200, nil]])
    end
  end

  describe "closing a session" do
    it "adds its length to the task's total" do
      task = running
      operation(:reopen_task).call(task.id, at: started + 600)

      expect(repo.by_id(task.id).worked_seconds).to eq(600)
    end

    it "adds each session to the total" do
      task = running
      operation(:reopen_task).call(task.id, at: started + 600)
      operation(:start_task).call(task.id, at: started + 1200)
      operation(:complete_task).call(task.id, at: started + 1500)

      expect(repo.by_id(task.id).worked_seconds).to eq(900)
    end

    it "adds to a total already on the task" do
      task = running
      repo.update(task.id, worked_seconds: 3600)
      operation(:complete_task).call(task.id, at: started + 60)

      expect(repo.by_id(task.id).worked_seconds).to eq(3660)
    end

    it "leaves the total alone when no session is open" do
      task = create(:task, worked_seconds: 120)
      operation(:complete_task).call(task.id)

      expect(repo.by_id(task.id).worked_seconds).to eq(120)
    end
  end

  describe "a task that stops being in progress" do
    it "ends the session when it is completed" do
      task = running
      operation(:complete_task).call(task.id, at: started + 60)

      expect(sessions(task).first[:ended_at]).to eq(started + 60)
    end

    it "ends the session when it is canceled" do
      task = running
      operation(:cancel_task).call(task.id, at: started + 60)

      expect(sessions(task).first[:ended_at]).to eq(started + 60)
    end

    it "ends the session when it moves out of Today" do
      task = running
      send_to("/admin/tasks/#{task.id}/move/next")

      expect(sessions(task).first[:ended_at]).to be_within(5).of(Time.now)
    end

    it "keeps the session open when it moves into Today" do
      task = create(:task, :in_progress)
      create(:work_session, task_id: task.id, started_at: started)
      send_to("/admin/tasks/#{task.id}/move/today")

      expect(open_sessions(task).size).to eq(1)
    end

    it "ends the session when it is scheduled for a later day" do
      task = running
      operation(:schedule_task).call(task.id, (today + 2).iso8601, now: started + 60)

      expect(sessions(task).first[:ended_at]).to eq(started + 60)
    end

    it "ends the session when it is unscheduled" do
      task = running
      operation(:schedule_task).call(task.id, "", now: started + 60)

      expect(sessions(task).first[:ended_at]).to eq(started + 60)
    end

    it "ends the session at the midnight rollover" do
      task = running(sprint: create(:sprint, sprint_date: today - 1))
      Tasks::Jobs::RollOverSprint.new.perform

      expect(sessions(task).first[:ended_at]).to be_within(5).of(Time.now)
    end

    it "opens a new session at the rollover while the task stays in progress", :aggregate_failures do
      task = running(sprint: create(:sprint, sprint_date: today - 1))
      rolled = Time.at(Time.now.to_i)
      Tasks::Operations::CurrentSprint.new.call(now: rolled)

      expect(sessions(task).map { [it[:started_at], it[:ended_at]] }).to eq([[started, rolled], [rolled, nil]])
      expect(repo.by_id(task.id).status).to eq("in_progress")
    end

    it "keeps the session whole when the day's sprint loads again" do
      task = running
      2.times { Tasks::Operations::CurrentSprint.new.call }

      expect(sessions(task).map { [it[:started_at], it[:ended_at]] }).to eq([[started, nil]])
    end

    it "ends the session when its sprint is dropped" do
      task = running(sprint: create(:sprint, sprint_date: today + 2))
      operation(:drop_sprint).call(task.sprint_id, now: started + 60)

      expect(sessions(task).first[:ended_at]).to eq(started + 60)
    end

    it "takes its sessions with it when it is deleted" do
      task = running
      send_to("/admin/tasks/#{task.id}/delete")

      expect(sessions(task)).to be_empty
    end
  end
end

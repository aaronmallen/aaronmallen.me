# frozen_string_literal: true

RSpec.describe "Work sessions", type: :request do
  let(:repo) { Tasks::Slice["repos.task_queries"] }
  let(:today) { Blog::TimeZone.today }
  let!(:started) { Time.at([Time.now.to_i - 5400, Blog::TimeZone.day_start(today).to_i].max) }

  def open_sessions(task) = sessions(task).select { it[:ended_at].nil? }

  def running(*traits, sprint: create(:sprint, sprint_date: today))
    task = create(:task, :in_progress, :in_sprint, *traits, sprint_id: sprint.id)
    create(:work_session, task_id: task.id, started_at: started)
    task
  end

  def send_at(time, path, **)
    allow(Time).to receive(:now).and_return(time)
    send_to(path, **)
    allow(Time).to receive(:now).and_call_original
  end

  def send_to(path, **params)
    post path, { _csrf_token: admin_csrf_token, **params }
  end

  def sessions(task) = Tasks::Slice["relations.work_sessions"].for_task(task.id).order(:started_at).to_a

  def spans(task) = sessions(task).map { [it[:started_at], it[:ended_at]] }

  before { sign_in_to_admin }

  describe "starting a task" do
    it "opens a session at that moment" do
      task = create(:task)
      send_at(started, "/admin/tasks/#{task.id}/start")

      expect(spans(task)).to eq([[started, nil]])
    end

    it "opens no second session for a task already in progress" do
      task = running
      send_to("/admin/tasks/#{task.id}/start")

      expect(sessions(task).size).to eq(1)
    end

    it "keeps the session whole while the task page loads on the day it started", :aggregate_failures do
      task = create(:task)
      send_at(started, "/admin/tasks/#{task.id}/start")
      2.times { get "/admin/tasks/#{task.id}" }

      expect(last_response.status).to eq(200)
      expect(spans(task)).to eq([[started, nil]])
    end
  end

  describe "pausing a task" do
    it "ends the open session" do
      task = running
      send_to("/admin/tasks/#{task.id}/stop")

      expect(sessions(task).first[:ended_at]).to be_within(5).of(Time.now)
    end

    it "opens a new session when the task starts again" do
      task = running
      send_at(started + 600, "/admin/tasks/#{task.id}/reopen")
      send_at(started + 1200, "/admin/tasks/#{task.id}/start")

      expect(spans(task)).to eq([[started, started + 600], [started + 1200, nil]])
    end
  end

  describe "closing a session" do
    it "adds its length to the task's total" do
      task = running
      send_at(started + 600, "/admin/tasks/#{task.id}/reopen")

      expect(repo.by_id(task.id).worked_seconds).to eq(600)
    end

    it "adds each session to the total" do
      task = running
      send_at(started + 600, "/admin/tasks/#{task.id}/reopen")
      send_at(started + 1200, "/admin/tasks/#{task.id}/start")
      send_at(started + 1500, "/admin/tasks/#{task.id}/complete")

      expect(repo.by_id(task.id).worked_seconds).to eq(900)
    end

    it "adds to a total already on the task" do
      task = running
      Tasks::Slice["repos.task_mutations"].update(task.id, worked_seconds: 3600)
      send_at(started + 60, "/admin/tasks/#{task.id}/complete")

      expect(repo.by_id(task.id).worked_seconds).to eq(3660)
    end

    it "leaves the total alone when no session is open" do
      task = create(:task, worked_seconds: 120)
      send_to("/admin/tasks/#{task.id}/complete")

      expect(repo.by_id(task.id).worked_seconds).to eq(120)
    end
  end

  describe "a task that stops being in progress" do
    it "ends the session when it is completed" do
      task = running
      send_at(started + 60, "/admin/tasks/#{task.id}/complete")

      expect(sessions(task).first[:ended_at]).to eq(started + 60)
    end

    it "ends the session when it is canceled" do
      task = running
      send_at(started + 60, "/admin/tasks/#{task.id}/cancel")

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
      send_at(started + 60, "/admin/tasks/#{task.id}/schedule", sprint_on: (today + 2).iso8601)

      expect(sessions(task).first[:ended_at]).to eq(started + 60)
    end

    it "ends the session when it is unscheduled" do
      task = running
      send_at(started + 60, "/admin/tasks/#{task.id}/schedule", sprint_on: "")

      expect(sessions(task).first[:ended_at]).to eq(started + 60)
    end

    it "keeps the session whole when the day's sprint loads again" do
      task = running
      2.times { get "/admin/tasks" }

      expect(spans(task)).to eq([[started, nil]])
    end

    it "ends the session when its sprint is dropped" do
      task = running(sprint: create(:sprint, sprint_date: today + 2))
      send_at(started + 60, "/admin/tasks/sprints/#{task.sprint_id}/delete")

      expect(sessions(task).first[:ended_at]).to eq(started + 60)
    end

    it "takes its sessions with it when it is deleted" do
      task = running
      send_to("/admin/tasks/#{task.id}/delete")

      expect(sessions(task)).to be_empty
    end
  end
end

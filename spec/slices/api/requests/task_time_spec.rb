# frozen_string_literal: true

RSpec.describe "API task time", type: :request do
  let(:started) { Time.at(((Time.now.to_i - 86_400) / 60) * 60) }
  let(:task) { create(:task, worked_seconds: 3600) }

  def act(id, verb, fields = {}) = call_api(:post, "/#{id}/#{verb}", JSON.generate(fields))

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(verb, path, body = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    public_send(verb, "/api/v1/tasks#{path}", body, headers)
    JSON.parse(last_response.body)
  end

  def closed(from: started, to: started + 1800, on: task)
    create(:work_session, task_id: on.id, started_at: from, ended_at: to)
  end

  def edit(session, on: task, **times)
    call_api(:patch, "/#{on.id}/sessions/#{session[:id]}", JSON.generate(times.transform_values { local(it) }))
  end

  def local(time) = time.is_a?(Time) ? Blog::TimeZone.input_value(time) : time

  def remove(session, on: task) = call_api(:delete, "/#{on.id}/sessions/#{session[:id]}")

  def running_task(since: started)
    found = create(:task, :in_progress, :in_sprint, worked_seconds: 600)
    create(:work_session, task_id: found.id, started_at: since)
    found
  end

  def sessions(on = task) = Tasks::Slice["relations.work_sessions"].for_task(on.id).order(:started_at).to_a

  def status = last_response.status

  def total(on = task) = Tasks::Slice["repos.task_repo"].by_id(on.id).worked_seconds

  describe "POST /api/v1/tasks/:id/pause" do
    it "ends the open session and returns the task to open", :aggregate_failures do
      found = running_task

      expect(act(found.id, "pause")).to include("status" => "open", "worked_seconds" => be > 600)
      expect(sessions(found).map { it[:ended_at] }).to all(be_a(Time))
    end

    it "keeps the task in its sprint" do
      found = running_task

      expect(act(found.id, "pause").fetch("sprint_on")).not_to be_nil
    end

    it "lets start_task resume it with a new session" do
      found = running_task
      act(found.id, "pause")
      act(found.id, "start")

      expect(sessions(found).map { it[:ended_at].nil? }).to eq([false, true])
    end

    it "refuses a task that is not in progress with a 422" do
      expect([act(task.id, "pause").fetch("message"), status])
        .to eq(["task #{task.id} is not in progress", 422])
    end

    it "answers an unknown ID with a 404" do
      expect([act(999_999, "pause").fetch("message"), status]).to eq(["no task has the ID 999999", 404])
    end
  end

  describe "PATCH /api/v1/tasks/:id/sessions/:session_id" do
    it "shifts the total by a later end", :aggregate_failures do
      answer = edit(closed, started_at: started, ended_at: started + 2700)

      expect(sessions.first[:ended_at]).to eq(started + 2700)
      expect(answer.fetch("worked_seconds")).to eq(4500)
    end

    it "shifts the total by a later start" do
      edit(closed, started_at: started + 600, ended_at: started + 1800)

      expect(total).to eq(3000)
    end

    it "moves the start of the running session and leaves the total alone", :aggregate_failures do
      found = running_task
      edit(sessions(found).first, on: found, started_at: started - 600)

      expect(sessions(found).first[:started_at]).to eq(started - 600)
      expect(total(found)).to eq(600)
    end

    it "refuses an end before the start with a 422 and keeps the session", :aggregate_failures do
      answer = edit(closed, started_at: started, ended_at: started - 60)

      expect([answer.fetch("errors"), status]).to eq([{ "ended_at" => ["a session ends after it starts"] }, 422])
      expect(total).to eq(3600)
    end

    it "refuses a finished session with no end with a 422" do
      expect(edit(closed, started_at: started).fetch("errors"))
        .to eq("ended_at" => ["a finished session needs an end"])
    end

    it "refuses a time it cannot read with a 422" do
      expect(edit(closed, started_at: "yesterday", ended_at: started).fetch("errors"))
        .to eq("started_at" => ["give the start as YYYY-MM-DDTHH:MM"])
    end

    it "refuses a request with no start" do
      call_api(:patch, "/#{task.id}/sessions/#{closed.id}", JSON.generate(ended_at: local(started)))

      expect(status).to eq(422)
    end

    it "answers a session on another task with a 404" do
      other = closed(on: create(:task))

      expect([edit(other, started_at: started, ended_at: started + 60).fetch("message"), status])
        .to eq(["task #{task.id} has no work session with the ID #{other.id}", 404])
    end
  end

  describe "DELETE /api/v1/tasks/:id/sessions/:session_id" do
    it "drops the total by the session's length", :aggregate_failures do
      answer = remove(closed)

      expect(sessions).to be_empty
      expect(answer.fetch("worked_seconds")).to eq(1800)
    end

    it "leaves the total alone for the running session", :aggregate_failures do
      found = running_task
      remove(sessions(found).first, on: found)

      expect(sessions(found)).to be_empty
      expect(total(found)).to eq(600)
    end

    it "answers a session on another task with a 404 and keeps it", :aggregate_failures do
      owner = create(:task)
      other = closed(on: owner)
      remove(other)

      expect(status).to eq(404)
      expect(sessions(owner).size).to eq(1)
    end
  end

  describe "POST /api/v1/tasks/:id/total" do
    it "replaces the total" do
      expect(act(task.id, "total", hours: 2, minutes: 15).fetch("worked_seconds")).to eq(8100)
    end

    it "takes the minutes alone" do
      expect(act(task.id, "total", minutes: 45).fetch("worked_seconds")).to eq(2700)
    end

    it "lets a later session add to the total it set", :aggregate_failures do
      found = running_task(since: Time.now - 600)
      act(found.id, "total", hours: 1)
      Tasks::Slice["operations.complete_task"].call(found.id)

      expect(total(found)).to be_between(3600, 3660)
    end

    it "refuses a total with no hours or minutes with a 422 and keeps the old one", :aggregate_failures do
      expect([act(task.id, "total").fetch("errors"), status])
        .to eq([{ "hours" => ["give the hours, the minutes or both"] }, 422])
      expect(total).to eq(3600)
    end

    it "refuses minutes past 59 with a 422" do
      expect(act(task.id, "total", minutes: 60).fetch("errors")).to eq("minutes" => ["minutes run from 0 to 59"])
    end

    it "answers an unknown ID with a 404" do
      expect([act(999_999, "total", hours: 1).fetch("message"), status]).to eq(["no task has the ID 999999", 404])
    end
  end

  describe "POST /api/v1/tasks/:id/complete" do
    it "keeps the tracked total when it names no duration" do
      expect(act(task.id, "complete")).to include("status" => "done", "worked_seconds" => 3600)
    end

    it "replaces the total with the duration it names" do
      expect(act(task.id, "complete", hours: 0, minutes: 30)).to include("status" => "done", "worked_seconds" => 1800)
    end

    it "closes the running session before the duration replaces the total", :aggregate_failures do
      found = running_task
      answer = act(found.id, "complete", hours: 3)

      expect(answer.fetch("worked_seconds")).to eq(10_800)
      expect(sessions(found).first[:ended_at]).to be_a(Time)
    end

    it "refuses hours past 9999 with a 422 and leaves the task open", :aggregate_failures do
      expect(act(task.id, "complete", hours: 10_000).fetch("errors")).to eq("hours" => ["hours run from 0 to 9999"])
      expect(Tasks::Slice["repos.task_repo"].by_id(task.id).status).to eq("open")
    end
  end

  describe "the total on a read" do
    it "comes back from read_task" do
      expect(call_api(:get, "/#{task.id}").fetch("worked_seconds")).to eq(3600)
    end

    it "comes back on each task from list_tasks" do
      task

      expect(call_api(:get, "").fetch("tasks").map { it.fetch("worked_seconds") }).to eq([3600])
    end
  end

  describe "the MCP tools" do
    it "pause as pause_task does" do
      ids = [create(:task, title: "same").id, create(:task, title: "same").id]
      ids.each { act(it, "start") }
      paused = act(ids.first, "pause")

      expect(mcp_answer("pause_task", id: ids.last).except("id", "created_at", "worked_seconds"))
        .to eq(paused.except("id", "created_at", "worked_seconds"))
    end

    it "edit a session as update_work_session does" do
      times = { started_at: local(started), ended_at: local(started + 900) }
      edited = edit(closed, **times)

      expect(mcp_answer("update_work_session", id: task.id, session_id: sessions.first[:id], **times)).to eq(edited)
    end

    it "delete a session as delete_work_session does" do
      sessions_made = [closed, closed(from: started + 3600, to: started + 3900)]
      remove(sessions_made.first)

      expect(mcp_answer("delete_work_session", id: task.id, session_id: sessions_made.last.id))
        .to include("worked_seconds" => 1500)
    end

    it "set the total as set_task_total does" do
      set = act(task.id, "total", hours: 4)

      expect(mcp_answer("set_task_total", id: task.id, hours: 4)).to eq(set)
    end

    it "complete with a duration as complete_task does" do
      ids = [create(:task, title: "same").id, create(:task, title: "same").id]
      completed = act(ids.first, "complete", minutes: 20)

      expect(mcp_answer("complete_task", id: ids.last, minutes: 20).except("id", "completed_at", "created_at"))
        .to eq(completed.except("id", "completed_at", "created_at"))
    end

    it "refuse with the message the endpoint gives" do
      refused = act(task.id, "pause")

      expect(mcp_text("pause_task", id: task.id)).to eq(refused.fetch("message"))
    end
  end
end

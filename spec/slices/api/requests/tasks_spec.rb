# frozen_string_literal: true

RSpec.describe "API tasks", type: :request do
  def act(id, verb, fields = {}) = call_api(:post, "/#{id}/#{verb}", JSON.generate(fields))

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def at(day, hour = 12, minute = 0) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour, minute)

  def call_api(verb, path, body = nil, token: api_token)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    public_send(verb, "/api/v1/tasks#{path}", body, headers)
    JSON.parse(last_response.body)
  end

  def capture(fields) = call_api(:post, "", JSON.generate(fields))

  def link(kind, id, other_kind, other_id)
    Links::Slice["operations.link_records"].call(kind, id, { other_kind:, other_id: }).value!
  end

  def list(query = {}) = call_api(:get, "", query)

  def read(id) = call_api(:get, "/#{id}")

  def save(id, fields) = call_api(:patch, "/#{id}", JSON.generate(fields))

  def status = last_response.status

  def tasks = Tasks::Slice["repos.task_repo"]

  def titles(answer) = answer.fetch("tasks").map { it.fetch("title") }

  def today = Blog::TimeZone.today

  describe "GET /api/v1/tasks" do
    it "lists tasks in every status, newest first" do
      create(:task, title: "older", created_at: at(today - 2))
      create(:task, :done, title: "newer", created_at: at(today), completed_at: at(today))

      expect([titles(list), status]).to eq([%w[newer older], 200])
    end

    it "narrows to the statuses it names" do
      create(:task, title: "open")
      create(:task, :done, title: "finished")
      create(:task, :canceled, title: "dropped")

      expect(titles(list("statuses[]" => %w[done canceled]))).to contain_exactly("finished", "dropped")
    end

    it "takes the statuses as a list split by commas" do
      create(:task, title: "open")
      create(:task, :in_progress, title: "started")
      create(:task, :done, title: "finished")

      expect(titles(list(statuses: "open,in_progress"))).to contain_exactly("open", "started")
    end

    it "keeps a task created or finished inside the window" do
      create(:task, title: "made inside", created_at: at(today - 3))
      create(:task, :done, title: "outside", created_at: at(today - 30), completed_at: at(today - 20))

      expect(titles(list(from: (today - 5).iso8601, to: today.iso8601))).to eq(["made inside"])
    end

    describe "paging" do
      before do
        3.times { create(:task) }
        lower_page_size(:mcp, to: 2)
      end

      it "answers a page and says more remain" do
        expect(list).to include("count" => 2, "partial" => true, "next_page" => 2)
      end

      it "answers the rest from the page it names" do
        expect(list(page: "2")).to include("count" => 1, "partial" => false)
      end

      it "refuses a page before the first with a 422" do
        expect([list(page: "0").fetch("errors").keys, status]).to eq([%w[page], 422])
      end

      it "refuses a page that is not a number with a 422" do
        expect([list(page: "two").fetch("errors").keys, status]).to eq([%w[page], 422])
      end
    end

    it "gives each task its source and when it last changed" do
      synced = create(:task, updated_at: at(today, 15))
      create(:task_source, task_id: synced.id, url: "https://github.com/aaronmallen/aaronmallen.me/issues/7")
      create(:task, updated_at: at(today, 16))

      expect(list.fetch("tasks").map { [it.dig("source", "reference"), it.fetch("updated_at")] })
        .to eq([[nil, at(today, 16).utc.iso8601], ["aaronmallen/aaronmallen.me#7", at(today, 15).utc.iso8601]])
    end

    it "refuses a window that runs backwards with a 422" do
      refusal = { "error" => "invalid", "message" => "from comes after to",
                  "errors" => { "from" => ["from comes after to"], "to" => ["from comes after to"] } }

      expect([list(from: today.iso8601, to: (today - 1).iso8601), status]).to eq([refusal, 422])
    end

    it "refuses a day it cannot read with a 422" do
      expect([list(from: "last week").fetch("message"), status])
        .to eq(["give from and to as days, such as 2026-01-01", 422])
    end

    it "refuses a status it does not know with a 422" do
      expect([list(statuses: "lost").fetch("errors").keys, status]).to eq([%w[statuses], 422])
    end

    it "refuses a request with no token" do
      call_api(:get, "", nil, token: nil)

      expect(status).to eq(401)
    end
  end

  describe "GET /api/v1/tasks/:id" do
    it "answers the task with its comments, oldest first" do
      task = create(:task, title: "Read me")
      create(:task_comment, task_id: task.id, body: "second", created_at: at(today, 14))
      create(:task_comment, task_id: task.id, body: "first", created_at: at(today, 9))

      expect(read(task.id)).to include("title" => "Read me", "comments" => [include("body" => "first"),
                                                                            include("body" => "second")])
    end

    it "answers the records linked to the task, grouped by kind" do
      task = create(:task)
      post = create(:post, title: "On hosting")
      link("task", task.id, "post", post.id)

      expect(read(task.id).fetch("record_links"))
        .to match("post" => [include("kind" => "post", "id" => post.id, "title" => "On hosting")])
    end

    it "answers the decisions the task carries out" do
      task = create(:task)
      decision = create(:decision, title: "Pick a queue")
      link("decision", decision.id, "task", task.id)

      expect(read(task.id).fetch("record_links"))
        .to match("decision" => [include("kind" => "decision", "id" => decision.id, "title" => "Pick a queue")])
    end

    it "answers the same record links as read_task" do
      task = create(:task)
      link("task", task.id, "journal_entry", create(:journal_entry).id)

      expect(read(task.id).fetch("record_links")).to eq(mcp_answer("read_task", id: task.id).fetch("record_links"))
    end

    it "answers no record links for a task with none" do
      expect(read(create(:task).id).fetch("record_links")).to eq({})
    end

    it "answers when the task last changed" do
      task = create(:task, updated_at: at(today, 15))

      expect(read(task.id).fetch("updated_at")).to eq(at(today, 15).utc.iso8601)
    end

    it "answers the GitHub issue a synced task comes from" do
      source = create(:task_source, remote_state: "completed", seen_at: at(today, 9))

      expect(read(source.task_id).fetch("source"))
        .to include("provider" => "github", "remote_state" => "completed", "seen_at" => at(today, 9).utc.iso8601)
    end

    it "answers the address and reference of the issue" do
      url = "https://github.com/aaronmallen/aaronmallen.me/issues/12"
      source = create(:task_source, url:)

      expect(read(source.task_id).fetch("source"))
        .to include("url" => url, "reference" => "aaronmallen/aaronmallen.me#12")
    end

    it "answers the Linear issue a synced task comes from, not yet seen" do
      task = create(:task)
      create(:task_source, task_id: task.id, provider: "linear", url: "https://linear.app/aaron/issue/AA-213/a-slug")

      expect(read(task.id).fetch("source"))
        .to include("provider" => "linear", "reference" => "aaron/AA-213", "remote_state" => "open", "seen_at" => nil)
    end

    it "answers a null source for a local task" do
      expect(read(create(:task).id).fetch("source")).to be_nil
    end

    it "answers an unknown ID with a 404" do
      expect([read(999_999), status])
        .to eq([{ "error" => "not_found", "message" => "no task has the ID 999999" }, 404])
    end

    it "refuses an ID that is not a number with a 422" do
      expect([read("abc").fetch("errors").keys, status]).to eq([%w[id], 422])
    end
  end

  describe "GET /api/v1/tasks/:id timeline" do
    let(:task) { create(:task) }

    def event(kind, hour, **fields)
      create(:task_event, task_id: task.id, kind:, tag_name: nil, occurred_at: at(today, hour), **fields)
    end

    def stamp(*) = at(*).utc.iso8601

    def timeline = read(task.id).fetch("timeline")

    context "with an entry of every kind" do
      before do
        event("untagged", 14, tag_name: "money")
        create(:work_session, task_id: task.id, started_at: at(today, 10), ended_at: at(today, 11))
        event("moved", 8, from_list: "next", to_sprint_on: today)
        event("tagged", 9, tag_name: "money")
        create(:task_comment, task_id: task.id, created_at: at(today, 12))
        event("status_changed", 13, from_status: "open", to_status: "in_progress")
      end

      it "lists them oldest first" do
        expect(timeline.map { it.fetch("kind") }).to eq(%w[moved tagged session comment status_changed untagged])
      end
    end

    it "says what a move changed" do
      event("moved", 8, from_list: "next", to_sprint_on: today)

      expect(timeline).to eq([{ "kind" => "moved", "occurred_at" => stamp(today, 8), "from_list" => "next",
                                "from_sprint_on" => nil, "to_list" => nil, "to_sprint_on" => today.iso8601 }])
    end

    it "says which tag went on or came off" do
      event("untagged", 9, tag_name: "money")

      expect(timeline).to eq([{ "kind" => "untagged", "occurred_at" => stamp(today, 9), "tag" => "money" }])
    end

    it "says what a status change changed" do
      event("status_changed", 9, from_status: "open", to_status: "done")

      expect(timeline).to eq([{ "kind" => "status_changed", "occurred_at" => stamp(today, 9),
                                "from_status" => "open", "to_status" => "done" }])
    end

    it "gives a comment its ID, body and author" do
      comment = create(:task_comment, task_id: task.id, body: "a note", created_at: at(today, 9))

      expect(timeline).to eq([{ "kind" => "comment", "id" => comment.id, "occurred_at" => stamp(today, 9),
                                "body" => "a note", "author" => Blog::Owner.full_name, "source" => "local",
                                "url" => nil }])
    end

    it "gives a session its ID, start, end and length" do
      session = create(:work_session, task_id: task.id, started_at: at(today, 9), ended_at: at(today, 10, 30))

      expect(timeline).to eq([{ "kind" => "session", "id" => session.id, "occurred_at" => stamp(today, 9),
                                "started_at" => stamp(today, 9), "ended_at" => stamp(today, 10, 30),
                                "seconds" => 5400, "running" => false }])
    end

    it "gives a running session no end and its length so far" do
      create(:work_session, task_id: task.id, started_at: Time.now - 600)

      expect(timeline.first).to include("ended_at" => nil, "running" => true, "seconds" => be_between(600, 660))
    end

    it "carries none for a task with no history" do
      expect(timeline).to eq([])
    end
  end

  describe "POST /api/v1/tasks" do
    it "captures a task into next with its tags" do
      expect(capture(title: "Email the accountant", tags: %w[admin money]))
        .to include("title" => "Email the accountant", "list" => "next", "tags" => %w[admin money])
    end

    it "answers 201" do
      capture(title: "Email the accountant")

      expect(status).to eq(201)
    end

    it "schedules a task for the sprint day it names" do
      expect(capture(title: "Later", sprint_on: (today + 3).iso8601).fetch("sprint_on")).to eq((today + 3).iso8601)
    end

    it "refuses a blank title with a 422 naming the field" do
      refusal = { "error" => "invalid", "message" => "title: write the task down first",
                  "errors" => { "title" => ["write the task down first"] } }

      expect([capture(title: "  "), status]).to eq([refusal, 422])
    end

    it "refuses a sprint day in the past with a 422 and captures nothing" do
      answer = capture(title: "Too late", sprint_on: (today - 1).iso8601)

      expect([answer.fetch("errors"), status, tasks.all_open])
        .to eq([{ "sprint_on" => ["a sprint opens on today or a day after it"] }, 422, []])
    end

    it "refuses a list it does not know with a 422" do
      expect([capture(title: "Lost", list: "nowhere").fetch("errors").keys, status]).to eq([%w[list], 422])
    end

    it "refuses a task with no title" do
      expect(capture(tags: %w[admin]).fetch("errors")).to eq("title" => ["title is missing"])
    end

    it "refuses a body that is not JSON with a 400" do
      expect([call_api(:post, "", "{nope"), status])
        .to eq([{ "error" => "invalid_json", "message" => "the body takes a JSON object" }, 400])
    end

    it "answers a failure it did not expect with a 500" do
      failing = instance_double(Tasks::Operations::CaptureTask, call: Dry::Monads::Failure(:unexpected))
      replace_component("tasks.operations.capture_task", failing)

      expect([capture(title: "Lost"), status])
        .to eq([{ "error" => "failed", "message" => "could not save the change" }, 500])
    end
  end

  describe "PATCH /api/v1/tasks/:id" do
    let(:task) { create(:task, title: "Draft", note: "the plan", tags: %w[admin]) }

    it "changes the fields it names and keeps the rest" do
      expect(save(task.id, title: "Final"))
        .to include("title" => "Final", "note" => "the plan", "tags" => %w[admin])
    end

    it "moves the task to the list it names" do
      save(task.id, list: "someday")

      expect(tasks.by_id(task.id).list).to eq("someday")
    end

    it "refuses a blank title with a 422 and keeps the old one" do
      save(task.id, title: "")

      expect([status, tasks.by_id(task.id).title]).to eq([422, "Draft"])
    end

    it "refuses a sprint day in the past with a 422" do
      expect([save(task.id, sprint_on: (today - 1).iso8601).fetch("errors").keys, status]).to eq([%w[sprint_on], 422])
    end

    it "refuses a sprint day for a closed task with a 422 and keeps its title", :aggregate_failures do
      done = create(:task, :done, title: "Draft", completed_at: Time.now - 60)

      expect([save(done.id, title: "Final", sprint_on: (today + 3).iso8601).fetch("message"), status])
        .to eq(["task #{done.id} is already done or canceled", 422])
      expect(tasks.by_id(done.id)).to have_attributes(title: "Draft", sprint_id: nil)
    end

    it "answers an unknown ID with a 404" do
      save(999_999, title: "Ghost")

      expect(status).to eq(404)
    end
  end

  describe "DELETE /api/v1/tasks/:id" do
    it "removes the task" do
      task = create(:task, title: "Gone")

      expect([call_api(:delete, "/#{task.id}"), tasks.by_id(task.id)])
        .to eq([{ "id" => task.id, "title" => "Gone", "deleted" => true }, nil])
    end

    it "answers an unknown ID with a 404" do
      call_api(:delete, "/999999")

      expect(status).to eq(404)
    end
  end

  describe "the status endpoints" do
    it "starts a task into today's sprint" do
      expect(act(create(:task).id, "start")).to include("status" => "in_progress", "sprint_on" => today.iso8601)
    end

    it "completes a task" do
      expect(act(create(:task).id, "complete").fetch("status")).to eq("done")
    end

    it "reopens a finished task" do
      expect(act(create(:task, :done).id, "reopen")).to include("status" => "open", "completed_at" => nil)
    end

    it "cancels an open task" do
      expect(act(create(:task).id, "cancel").fetch("status")).to eq("canceled")
    end

    it "refuses to cancel a finished task with a 422" do
      task = create(:task, :done)

      expect([act(task.id, "cancel").fetch("errors"), status])
        .to eq([{ "id" => ["task #{task.id} is already done or canceled"] }, 422])
    end

    %i[done canceled].each do |closed|
      it "refuses to complete a #{closed} task with a 422 and leaves it as it was", :aggregate_failures do
        task = create(:task, closed, completed_at: at(today - 1))

        expect([act(task.id, "complete").fetch("errors"), status])
          .to eq([{ "id" => ["task #{task.id} is already done or canceled"] }, 422])
        expect(tasks.by_id(task.id)).to have_attributes(status: closed.to_s, completed_at: at(today - 1))
      end
    end

    %w[start complete reopen cancel].each do |verb|
      it "answers #{verb} on an unknown ID with a 404" do
        expect([act(999_999, verb).fetch("message"), status]).to eq(["no task has the ID 999999", 404])
      end
    end
  end

  describe "POST /api/v1/tasks/:id/schedule" do
    it "schedules the task for a later sprint" do
      expect(act(create(:task).id, "schedule", sprint_on: (today + 1).iso8601).fetch("sprint_on"))
        .to eq((today + 1).iso8601)
    end

    it "sends a scheduled task back to next on an empty day" do
      task = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: today + 1).id)

      expect(act(task.id, "schedule", sprint_on: "")).to include("list" => "next", "sprint_on" => nil)
    end

    it "refuses a day in the past with a 422" do
      expect([act(create(:task).id, "schedule", sprint_on: (today - 1).iso8601).fetch("message"), status])
        .to eq(["a sprint opens on today or a day after it", 422])
    end

    it "refuses a request with no day" do
      expect(act(create(:task).id, "schedule").fetch("errors")).to eq("sprint_on" => ["sprint_on is missing"])
    end

    %i[done canceled].each do |closed|
      it "refuses a #{closed} task with a 422 and opens no sprint", :aggregate_failures do
        task = create(:task, closed, completed_at: Time.now - 60)

        expect([act(task.id, "schedule", sprint_on: (today + 3).iso8601).fetch("message"), status])
          .to eq(["task #{task.id} is already done or canceled", 422])
        expect(Tasks::Slice["repos.sprint_repo"].on(today + 3)).to be_nil
        expect(tasks.by_id(task.id)).to have_attributes(status: closed.to_s, sprint_id: nil)
      end
    end
  end

  describe "POST /api/v1/tasks/:id/seen" do
    def seen_at(task) = tasks.by_id(task.id).source.seen_at

    def synced
      task = create(:task, list: "external")
      create(:task_source, task:)
      task
    end

    it "marks a synced task seen and leaves it in its list", :aggregate_failures do
      task = synced

      expect([act(task.id, "seen"), status]).to match([include("id" => task.id, "list" => "external"), 200])
      expect(read(task.id).fetch("timeline")).to be_empty
      expect(seen_at(task)).not_to be_nil
    end

    it "refuses a task with no synced issue with a 422" do
      task = create(:task)

      expect([act(task.id, "seen").fetch("errors"), status])
        .to eq([{ "id" => ["task #{task.id} has no synced issue to mark seen"] }, 422])
    end

    it "answers an unknown ID with a 404" do
      expect([act(999_999, "seen").fetch("message"), status]).to eq(["no task has the ID 999999", 404])
    end
  end

  describe "POST /api/v1/tasks/:id/move" do
    it "moves the task to the list it names" do
      expect(act(create(:task).id, "move", list: "someday").fetch("list")).to eq("someday")
    end

    it "refuses a list it does not know with a 422" do
      expect([act(create(:task).id, "move", list: "nowhere").fetch("errors").keys, status]).to eq([%w[list], 422])
    end
  end

  describe "POST /api/v1/tasks/:id/reorder" do
    let!(:first) { create(:task, title: "first", position: 1) }
    let!(:second) { create(:task, title: "second", position: 2) }

    it "moves the task past the one above it" do
      act(second.id, "reorder", direction: "up")

      expect([tasks.in_list("next").map(&:title), JSON.parse(last_response.body).fetch("moved")])
        .to eq([%w[second first], true])
    end

    it "says it did not move a task already at the top" do
      expect(act(first.id, "reorder", direction: "up").fetch("moved")).to be(false)
    end

    it "refuses a direction it does not know with a 422" do
      expect([act(first.id, "reorder", direction: "sideways").fetch("errors").keys, status])
        .to eq([%w[direction], 422])
    end
  end

  describe "the MCP tools" do
    it "list as list_tasks does" do
      create(:task, :done, tags: %w[admin], completed_at: at(today))
      create(:task_link, from_task_id: create(:task).id, to_task_id: create(:task).id)

      expect(list(statuses: "open,done")).to eq(mcp_answer("list_tasks", statuses: %w[open done]))
    end

    it "read as read_task does" do
      task = create(:task, tags: %w[ruby])
      create(:task_comment, task_id: task.id)
      create(:work_session, :closed, task_id: task.id)
      create(:task_event, task_id: task.id)

      expect(read(task.id)).to eq(trusted(mcp_answer("read_task", id: task.id)))
    end

    it "capture as capture_task does" do
      fields = { title: "the same", list: "someday", tags: %w[ruby] }
      captured = capture(fields)

      expect(mcp_answer("capture_task", **fields).except("id", "created_at", "updated_at"))
        .to eq(captured.except("id", "created_at", "updated_at"))
    end

    it "save as save_task does" do
      task = create(:task, title: "Draft", tags: %w[admin])
      saved = save(task.id, title: "Final", note: "done looks like this")

      expect(mcp_answer("save_task", id: task.id, title: "Final", note: "done looks like this").except("updated_at"))
        .to eq(saved.except("updated_at"))
    end

    %w[start complete cancel].each do |verb|
      it "#{verb} as #{verb}_task does" do
        ids = [create(:task, title: "same").id, create(:task, title: "same").id]
        answered = act(ids.first, verb)

        expect(mcp_answer("#{verb}_task", id: ids.last).except("id", "completed_at", "created_at", "updated_at"))
          .to eq(answered.except("id", "completed_at", "created_at", "updated_at"))
      end
    end

    it "reopen as reopen_task does" do
      task = create(:task, :done)
      reopened = act(task.id, "reopen")

      expect(mcp_answer("reopen_task", id: task.id).except("updated_at")).to eq(reopened.except("updated_at"))
    end

    it "mark seen as mark_task_seen does" do
      task = create(:task, list: "external")
      create(:task_source, task:)
      seen = act(task.id, "seen")

      expect(mcp_answer("mark_task_seen", id: task.id).except("updated_at")).to eq(seen.except("updated_at"))
    end

    it "schedule as schedule_task does" do
      task = create(:task)
      scheduled = act(task.id, "schedule", sprint_on: (today + 2).iso8601)

      expect(mcp_answer("schedule_task", id: task.id, sprint_on: (today + 2).iso8601).except("updated_at"))
        .to eq(scheduled.except("updated_at"))
    end

    it "move as move_task does" do
      task = create(:task)
      moved = act(task.id, "move", list: "external")

      expect(mcp_answer("move_task", id: task.id, list: "external").except("updated_at"))
        .to eq(moved.except("updated_at"))
    end

    it "reorder as reorder_task does" do
      task = create(:task)
      reordered = act(task.id, "reorder", direction: "up")

      expect(mcp_answer("reorder_task", id: task.id, direction: "up").except("updated_at"))
        .to eq(reordered.except("updated_at"))
    end

    it "delete as delete_task does" do
      ids = [create(:task, title: "same").id, create(:task, title: "same").id]
      deleted = call_api(:delete, "/#{ids.first}")

      expect(mcp_answer("delete_task", id: ids.last)).to eq(deleted.merge("id" => ids.last))
    end

    it "refuse with the message the endpoint gives" do
      refused = capture(title: " ")

      expect(mcp_text("capture_task", title: " ")).to eq(refused.fetch("message"))
    end
  end
end

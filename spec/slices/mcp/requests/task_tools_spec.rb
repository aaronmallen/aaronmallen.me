# frozen_string_literal: true

RSpec.describe "MCP task tools", type: :request do
  def access_token
    @access_token ||= mcp_connect(create(:oauth_client), verifier: MCP::OAuth::Secret.generate, scope: "read write")
                      .fetch("access_token")
  end

  def at(day, hour = 12) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour, 0)

  def call_tool(name, **arguments)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}" }
    body = { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name:, arguments: } }
    post "/mcp", JSON.generate(body), headers
  end

  def content = JSON.parse(message)

  def listed_titles = content.fetch("tasks").map { it.fetch("title") }

  def message = result.fetch("content").first.fetch("text")

  def refused? = result["isError"] == true

  def result = JSON.parse(last_response.body).fetch("result")

  def sprints = Tasks::Slice["repos.sprint_repo"]

  def tasks = Tasks::Slice["repos.task_repo"]

  def today = Blog::TimeZone.today

  def types = Tasks::Slice["repos.task_type_repo"]

  describe "list_tasks" do
    it "lists tasks in every status when it names none" do
      create(:task, title: "open")
      create(:task, :in_progress, title: "started")
      create(:task, :done, title: "finished")
      call_tool("list_tasks")

      expect(listed_titles).to contain_exactly("open", "started", "finished")
    end

    it "narrows to the statuses it names" do
      create(:task, title: "open")
      create(:task, :in_progress, title: "started")
      create(:task, :done, title: "finished")
      call_tool("list_tasks", statuses: %w[open in_progress])

      expect(listed_titles).to contain_exactly("open", "started")
    end

    describe "a finished task" do
      def entry = content.fetch("tasks").first

      before do
        chore = create(:task_type, name: "Chore")
        done = create(:task, :done, title: "finished", task_type_id: chore.id, tags: %w[admin], completed_at: at(today))
        create(:task_link, from_task_id: create(:task, title: "blocker").id, to_task_id: done.id)
        call_tool("list_tasks", statuses: %w[done])
      end

      it "carries its type and tags" do
        expect(entry).to include("task_type" => "Chore", "tags" => %w[admin])
      end

      it "carries a link stored on the other task" do
        expect(entry.fetch("links")).to contain_exactly(include("label" => "blocked_by", "title" => "blocker"))
      end

      it "carries its completed time" do
        expect(entry.fetch("completed_at")).to eq(at(today).utc.iso8601)
      end
    end

    it "keeps a task created or finished inside the window and drops the rest" do
      create(:task, title: "made inside", created_at: at(today - 3))
      create(:task, :done, title: "finished inside", created_at: at(today - 30), completed_at: at(today - 2))
      create(:task, :done, title: "outside", created_at: at(today - 30), completed_at: at(today - 20))
      call_tool("list_tasks", from: (today - 5).iso8601, to: today.iso8601)

      expect(listed_titles).to contain_exactly("made inside", "finished inside")
    end

    it "leaves the end of the window open when it names no to" do
      create(:task, title: "new", created_at: at(today))
      create(:task, title: "old", created_at: at(today - 30))
      call_tool("list_tasks", from: (today - 1).iso8601)

      expect(listed_titles).to eq(%w[new])
    end

    it "puts the newest first" do
      create(:task, title: "older", created_at: at(today - 2))
      create(:task, title: "newer", created_at: at(today))
      call_tool("list_tasks")

      expect(listed_titles).to eq(%w[newer older])
    end

    it "refuses a day it cannot read" do
      call_tool("list_tasks", from: "last week")

      expect(message).to eq("give from and to as days, such as 2026-01-01")
    end

    it "refuses a window that ends before it starts" do
      call_tool("list_tasks", from: today.iso8601, to: (today - 1).iso8601)

      expect(message).to eq("from comes after to")
    end
  end

  describe "read_task" do
    describe "a link" do
      let(:blocker) { create(:task, title: "blocker") }
      let(:blocked) { create(:task, title: "blocked") }

      before { create(:task_link, from_task_id: blocker.id, to_task_id: blocked.id) }

      it "shows on the task it runs from" do
        call_tool("read_task", id: blocker.id)

        expect(content.fetch("links").map { it.fetch("label") }).to eq(%w[blocks])
      end

      it "shows from the other end on the task it runs to" do
        call_tool("read_task", id: blocked.id)

        expect(content).to include("blocked" => true, "links" => [include("label" => "blocked_by")])
      end
    end

    it "names the sprint day of a task in a sprint" do
      sprint = create(:sprint, sprint_date: today + 2)
      task = create(:task, :in_sprint, sprint_id: sprint.id)
      call_tool("read_task", id: task.id)

      expect(content.fetch("sprint_on")).to eq((today + 2).iso8601)
    end

    it "refuses a task that is not there" do
      call_tool("read_task", id: 999_999)

      expect(message).to eq("no task has the ID 999999")
    end
  end

  describe "list_task_types" do
    it "lists each type with how many tasks carry it" do
      chore = create(:task_type, name: "Chore", position: 1)
      create(:task_type, name: "Bug", position: 2)
      create(:task, task_type_id: chore.id)
      call_tool("list_task_types")

      expect(content.fetch("task_types").map { it.values_at("name", "tasks") }).to eq([["Chore", 1], ["Bug", 0]])
    end
  end

  describe "list_sprints" do
    def dates = content.fetch("sprints").map { it.fetch("date") }

    before do
      [today - 1, today, today + 1].each { create(:sprint, sprint_date: it) }
    end

    it "lists today's sprint and the planned ones when it names no window" do
      call_tool("list_sprints")

      expect(dates).to eq([today, today + 1].map(&:iso8601))
    end

    it "leaves the start of the window open when it names no from" do
      call_tool("list_sprints", to: today.iso8601)

      expect(dates).to eq([today - 1, today].map(&:iso8601))
    end

    it "lists the sprints inside a window" do
      call_tool("list_sprints", from: (today - 1).iso8601, to: today.iso8601)

      expect(dates).to eq([today - 1, today].map(&:iso8601))
    end
  end

  describe "read_current_sprint" do
    it "opens today's sprint with its tasks", :aggregate_failures do
      sprint = create(:sprint, sprint_date: today)
      create(:task, :in_sprint, sprint_id: sprint.id, title: "today's work")
      call_tool("read_current_sprint")

      expect(content).to include("id" => sprint.id, "date" => today.iso8601)
      expect(content.fetch("tasks").map { it.values_at("title", "sprint_on") }).to eq([["today's work", today.iso8601]])
    end

    it "starts today's sprint when there is none" do
      call_tool("read_current_sprint")

      expect(sprints.on(today)).not_to be_nil
    end
  end

  describe "capture_task" do
    it "captures a task into next, reading a #word as a tag" do
      call_tool("capture_task", title: "Email the accountant #admin")

      expect(content).to include("title" => "Email the accountant", "tags" => %w[admin], "list" => "next")
    end

    it "captures a task into today's sprint" do
      call_tool("capture_task", title: "Ship it", list: "today")

      expect(content.fetch("sprint_on")).to eq(today.iso8601)
    end

    it "schedules a task for a later sprint" do
      call_tool("capture_task", title: "Later", sprint_on: (today + 3).iso8601)

      expect(content.fetch("sprint_on")).to eq((today + 3).iso8601)
    end

    it "sets the type it names" do
      chore = create(:task_type, name: "Chore")
      call_tool("capture_task", title: "Sweep", task_type_id: chore.id)

      expect(content.fetch("task_type")).to eq("Chore")
    end

    it "refuses a title with nothing in it, as the admin does" do
      call_tool("capture_task", title: "  ")

      expect(message).to eq("title: write the task down first")
    end

    it "refuses a sprint day in the past, as the admin does" do
      call_tool("capture_task", title: "Too late", sprint_on: (today - 1).iso8601)

      expect(message).to eq("a sprint opens on today or a day after it")
    end
  end

  describe "save_task" do
    let(:chore) { create(:task_type, name: "Chore") }
    let(:task) { create(:task, title: "Draft", note: "the plan", task_type_id: chore.id, tags: %w[admin]) }

    it "keeps every field it leaves out" do
      call_tool("save_task", id: task.id, title: "Final")

      expect(content).to include("title" => "Final", "note" => "the plan", "task_type" => "Chore", "tags" => %w[admin])
    end

    it "replaces the whole set of tags" do
      call_tool("save_task", id: task.id, tags: %w[site ruby])

      expect(tasks.by_id(task.id).tags.map(&:name)).to contain_exactly("site", "ruby")
    end

    it "clears the type on null" do
      call_tool("save_task", id: task.id, task_type_id: nil)

      expect(tasks.by_id(task.id).task_type_id).to be_nil
    end

    it "moves the task to the list it names" do
      call_tool("save_task", id: task.id, list: "someday")

      expect(tasks.by_id(task.id).list).to eq("someday")
    end

    it "refuses a blank title with the admin's reason" do
      call_tool("save_task", id: task.id, title: "")

      expect(message).to eq("title: write the task down first")
    end

    it "refuses a note holding a control character" do
      call_tool("save_task", id: task.id, note: "bad\u0000note")

      expect(message).to eq("note: holds a control character")
    end

    it "refuses a tag that is not a lowercase word" do
      call_tool("save_task", id: task.id, tags: ["two words!"])

      expect(message).to eq("tags: tags are lowercase words")
    end

    it "leaves the task alone when it refuses" do
      call_tool("save_task", id: task.id, title: "")

      expect(tasks.by_id(task.id).title).to eq("Draft")
    end

    it "refuses a task that is not there" do
      call_tool("save_task", id: 999_999, title: "Ghost")

      expect(message).to eq("no task has the ID 999999")
    end
  end

  describe "the status tools" do
    it "starts a task into today's sprint" do
      task = create(:task)
      call_tool("start_task", id: task.id)

      expect(content).to include("status" => "in_progress", "sprint_on" => today.iso8601)
    end

    it "completes a task" do
      task = create(:task)
      call_tool("complete_task", id: task.id)

      expect(content.fetch("status")).to eq("done")
    end

    it "reopens a finished task" do
      task = create(:task, :done)
      call_tool("reopen_task", id: task.id)

      expect(content).to include("status" => "open", "completed_at" => nil)
    end

    %w[start_task complete_task reopen_task delete_task].each do |name|
      it "refuses #{name} on a task that is not there", :aggregate_failures do
        call_tool(name, id: 999_999)

        expect(refused?).to be(true)
        expect(message).to eq("no task has the ID 999999")
      end
    end
  end

  describe "schedule_task" do
    let(:task) { create(:task) }

    it "schedules a task for a later sprint" do
      call_tool("schedule_task", id: task.id, sprint_on: (today + 1).iso8601)

      expect(content.fetch("sprint_on")).to eq((today + 1).iso8601)
    end

    it "sends a scheduled task back to next on an empty day" do
      scheduled = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: today + 1).id)
      call_tool("schedule_task", id: scheduled.id, sprint_on: "")

      expect(content).to include("list" => "next", "sprint_on" => nil)
    end

    it "refuses a day in the past, as the admin does" do
      call_tool("schedule_task", id: task.id, sprint_on: (today - 1).iso8601)

      expect(message).to eq("a sprint opens on today or a day after it")
    end
  end

  describe "move_task" do
    it "moves a task to someday" do
      task = create(:task)
      call_tool("move_task", id: task.id, list: "someday")

      expect(content.fetch("list")).to eq("someday")
    end

    it "moves a task into today's sprint" do
      task = create(:task)
      call_tool("move_task", id: task.id, list: "today")

      expect(content).to include("list" => nil, "sprint_on" => today.iso8601)
    end
  end

  describe "reorder_task" do
    let!(:first) { create(:task, title: "first", position: 1) }
    let!(:second) { create(:task, title: "second", position: 2) }

    it "moves a task past the one above it" do
      call_tool("reorder_task", id: second.id, direction: "up")

      expect(tasks.in_list("next").map(&:title)).to eq(%w[second first])
    end

    it "says it did not move a task already at the top" do
      call_tool("reorder_task", id: first.id, direction: "up")

      expect(content.fetch("moved")).to be(false)
    end
  end

  describe "delete_task" do
    it "deletes the task" do
      task = create(:task)
      call_tool("delete_task", id: task.id)

      expect(tasks.by_id(task.id)).to be_nil
    end
  end

  describe "link_tasks" do
    let(:task) { create(:task, title: "Ship") }
    let(:other) { create(:task, title: "Migrate") }

    it "stores a blocked_by link from the other end" do
      call_tool("link_tasks", id: task.id, kind: "blocked_by", other_id: other.id)

      expect(tasks.by_id(other.id).links.map(&:label)).to eq(%w[blocks])
    end

    it "shows the new link on the task" do
      call_tool("link_tasks", id: task.id, kind: "relates", other_id: other.id)

      expect(content.fetch("links")).to contain_exactly(include("label" => "relates", "id" => other.id))
    end

    it "refuses a link to itself with the admin's reason" do
      call_tool("link_tasks", id: task.id, kind: "relates", other_id: task.id)

      expect(message).to eq("other_id: a task cannot link to itself")
    end

    it "refuses a second link between the same pair" do
      create(:task_link, from_task_id: other.id, to_task_id: task.id)
      call_tool("link_tasks", id: task.id, kind: "relates", other_id: other.id)

      expect(message).to eq("other_id: these two tasks are already linked")
    end

    it "refuses a task that is gone" do
      call_tool("link_tasks", id: task.id, kind: "relates", other_id: 999_999)

      expect(message).to eq("other_id: that task is gone, so find another")
    end
  end

  describe "unlink_task" do
    let(:task) { create(:task) }
    let(:other) { create(:task) }

    it "removes the link from whichever end" do
      create(:task_link, from_task_id: other.id, to_task_id: task.id)
      call_tool("unlink_task", id: task.id, other_id: other.id)

      expect(content.fetch("links")).to be_empty
    end

    it "refuses a pair with no link" do
      call_tool("unlink_task", id: task.id, other_id: other.id)

      expect(message).to eq("task #{task.id} has no link to task #{other.id}")
    end
  end

  describe "save_task_type" do
    it "adds a type" do
      call_tool("save_task_type", name: "Chore", color: "mk-blue", icon: "broom")

      expect(types.all.map { [it.name, it.color, it.icon] }).to eq([%w[Chore mk-blue broom]])
    end

    it "renames a type and keeps its colour" do
      chore = create(:task_type, name: "Chore", color: "mk-green")
      call_tool("save_task_type", id: chore.id, name: "Errand")

      expect(content).to include("name" => "Errand", "color" => "mk-green")
    end

    it "clears the icon on an empty string" do
      chore = create(:task_type, name: "Chore", icon: "broom")
      call_tool("save_task_type", id: chore.id, name: "Chore", icon: "")

      expect(types.by_id(chore.id).icon).to be_nil
    end

    it "refuses a name another type holds, as the admin does" do
      create(:task_type, name: "Chore")
      call_tool("save_task_type", name: "Chore")

      expect(message).to eq("name: another type already holds that name")
    end

    it "refuses an icon it does not know" do
      call_tool("save_task_type", name: "Chore", icon: "not-an-icon")

      expect(message).to eq("icon: no free solid icon goes by that name")
    end

    it "refuses a type that is not there" do
      call_tool("save_task_type", id: 999_999, name: "Ghost")

      expect(message).to eq("no task type has the ID 999999")
    end
  end

  describe "reorder_task_type" do
    it "moves a type past the one above it" do
      create(:task_type, name: "Chore", position: 1)
      bug = create(:task_type, name: "Bug", position: 2)
      call_tool("reorder_task_type", id: bug.id, direction: "up")

      expect(types.all.map(&:name)).to eq(%w[Bug Chore])
    end
  end

  describe "remove_task_type" do
    it "removes a type no task carries" do
      chore = create(:task_type)
      call_tool("remove_task_type", id: chore.id)

      expect(types.by_id(chore.id)).to be_nil
    end

    it "keeps a type a task still carries, as the admin does", :aggregate_failures do
      chore = create(:task_type)
      create(:task, task_type_id: chore.id)
      call_tool("remove_task_type", id: chore.id)

      expect(message).to eq("kept: 1 task still carries it")
      expect(types.by_id(chore.id)).not_to be_nil
    end
  end

  describe "plan_sprint" do
    it "plans a sprint for a later day" do
      call_tool("plan_sprint", sprint_on: (today + 2).iso8601)

      expect(sprints.on(today + 2)).not_to be_nil
    end

    it "refuses today, as the admin does" do
      call_tool("plan_sprint", sprint_on: today.iso8601)

      expect(message).to eq("plan a sprint for a day after today")
    end

    it "refuses a day that already has one" do
      create(:sprint, sprint_date: today + 2)
      call_tool("plan_sprint", sprint_on: (today + 2).iso8601)

      expect(message).to eq("a sprint already exists for #{(today + 2).iso8601}")
    end

    it "refuses a day it cannot read" do
      call_tool("plan_sprint", sprint_on: "soon")

      expect(message).to eq("pick a day first, such as 2026-01-01")
    end
  end

  describe "drop_sprint" do
    it "drops a planned sprint and sends its tasks back to next", :aggregate_failures do
      sprint = create(:sprint, sprint_date: today + 2)
      task = create(:task, :in_sprint, sprint_id: sprint.id)
      call_tool("drop_sprint", id: sprint.id)

      expect(sprints.by_id(sprint.id)).to be_nil
      expect(tasks.by_id(task.id).list).to eq("next")
    end

    it "refuses a sprint that has started, as the admin does" do
      call_tool("drop_sprint", id: create(:sprint, sprint_date: today).id)

      expect(message).to eq("that sprint has already started")
    end

    it "refuses a sprint that is not there" do
      call_tool("drop_sprint", id: 999_999)

      expect(message).to eq("no sprint has the ID 999999")
    end
  end
end

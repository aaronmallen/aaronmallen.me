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

  def local_entry(body, time)
    { "body" => body, "author" => Blog::Owner.full_name, "source" => "local", "url" => nil,
      "created_at" => time.utc.iso8601 }
  end

  def message = result.fetch("content").first.fetch("text")

  def refused? = result["isError"] == true

  def result = JSON.parse(last_response.body).fetch("result")

  def sprints = Tasks::Slice["repos.sprint_repo"]

  def tasks = Tasks::Slice["repos.task_repo"]

  def today = Blog::TimeZone.today

  describe "list_tasks" do
    it "lists tasks in every status when it names none" do
      create(:task, title: "open")
      create(:task, :in_progress, title: "started")
      create(:task, :done, title: "finished")
      call_tool("list_tasks")

      expect(listed_titles).to contain_exactly("open", "started", "finished")
    end

    it "tells a canceled task from a done one" do
      create(:task, :done, title: "finished")
      create(:task, :canceled, title: "dropped")
      call_tool("list_tasks", statuses: %w[canceled])

      expect(content.fetch("tasks")).to contain_exactly(include("title" => "dropped", "status" => "canceled"))
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
        done = create(:task, :done, title: "finished", tags: %w[admin], completed_at: at(today))
        create(:task_link, from_task_id: create(:task, title: "blocker").id, to_task_id: done.id)
        call_tool("list_tasks", statuses: %w[done])
      end

      it "carries its tags and no type", :aggregate_failures do
        expect(entry).to include("tags" => %w[admin])
        expect(entry.keys.grep(/type/)).to be_empty
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

      it "stops blocking once the blocker is canceled" do
        freed = create(:task, title: "freed")
        create(:task_link, from_task_id: create(:task, :canceled).id, to_task_id: freed.id)
        call_tool("read_task", id: freed.id)

        expect(content).to include("blocked" => false)
      end
    end

    it "names the sprint day of a task in a sprint" do
      sprint = create(:sprint, sprint_date: today + 2)
      task = create(:task, :in_sprint, sprint_id: sprint.id)
      call_tool("read_task", id: task.id)

      expect(content.fetch("sprint_on")).to eq((today + 2).iso8601)
    end

    it "shows a canceled task as canceled, with the time it closed" do
      task = create(:task, :canceled, completed_at: at(today))
      call_tool("read_task", id: task.id)

      expect(content).to include("status" => "canceled", "completed_at" => at(today).utc.iso8601)
    end

    it "loads the task once" do
      task = create(:task)
      reads = counting { call_tool("read_task", id: task.id) }

      expect(reads.grep(/FROM "tasks" WHERE \("tasks"."id" = #{task.id}\)/)).to have(1).item
    end

    it "gives each work session in its timeline the ID update_work_session takes" do
      task = create(:task)
      session = create(:work_session, :closed, task_id: task.id)
      call_tool("read_task", id: task.id)

      expect(content.fetch("timeline")).to match([include("kind" => "session", "id" => session.id)])
    end

    it "refuses a task that is not there" do
      call_tool("read_task", id: 999_999)

      expect(message).to eq("no task has the ID 999999")
    end

    describe "comments" do
      let(:task) { create(:task) }

      def comments = content.fetch("comments")

      it "carries none when the task has none" do
        call_tool("read_task", id: task.id)

        expect(comments).to eq([])
      end

      it "lists them oldest first" do
        create(:task_comment, task_id: task.id, body: "second", created_at: at(today, 14))
        create(:task_comment, task_id: task.id, body: "first", created_at: at(today, 9))
        call_tool("read_task", id: task.id)

        expect(comments.map { it.fetch("body") }).to eq(%w[first second])
      end

      it "leaves out another task's comments" do
        create(:task_comment, body: "elsewhere")
        call_tool("read_task", id: task.id)

        expect(comments).to be_empty
      end

      it "names the owner as the author of a local comment" do
        create(:task_comment, task_id: task.id, body: "mine", created_at: at(today, 9))
        call_tool("read_task", id: task.id)

        expect(comments.first).to include(local_entry("mine", at(today, 9)))
      end

      it "names the provider, author and link of a synced comment" do
        synced = create(:task_comment, :synced, task_id: task.id, author: "octocat")
        call_tool("read_task", id: task.id)

        expect(comments.first).to include("author" => "octocat", "source" => "github", "url" => synced.url)
      end
    end
  end

  describe "add_task_comment" do
    let(:task) { create(:task) }

    def stored = Tasks::Slice["repos.task_comment_repo"].for_task(task.id)

    it "adds a local comment to the task" do
      call_tool("add_task_comment", id: task.id, body: "Blocked on review")

      expect(stored.map { [it.body, it.remote_id] }).to eq([["Blocked on review", nil]])
    end

    it "answers with the comment, trimmed" do
      call_tool("add_task_comment", id: task.id, body: "  Blocked on review  ")

      expect(content).to eq({ "id" => stored.first.id, **local_entry("Blocked on review", stored.first.created_at) })
    end

    it "shows the comment when the task is read" do
      call_tool("add_task_comment", id: task.id, body: "Blocked on review")
      call_tool("read_task", id: task.id)

      expect(content.fetch("comments").map { it.fetch("body") }).to eq(["Blocked on review"])
    end

    it "refuses an empty body and adds nothing", :aggregate_failures do
      call_tool("add_task_comment", id: task.id, body: "   ")

      expect([refused?, message]).to eq([true, "body: write the comment first"])
      expect(stored).to be_empty
    end

    it "refuses a body holding a control character" do
      call_tool("add_task_comment", id: task.id, body: "bad\u0000body")

      expect(message).to eq("body: holds a control character")
    end

    it "refuses a task that is not there", :aggregate_failures do
      call_tool("add_task_comment", id: 999_999, body: "Hello")

      expect([refused?, message]).to eq([true, "no task has the ID 999999"])
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
    it "captures a task into next" do
      call_tool("capture_task", title: "Email the accountant")

      expect(content).to include("title" => "Email the accountant", "list" => "next")
    end

    it "applies the tags it is given" do
      call_tool("capture_task", title: "Email the accountant", tags: %w[admin money])

      expect(content.fetch("tags")).to contain_exactly("admin", "money")
    end

    it "keeps a #word in the title and adds no tag for it" do
      call_tool("capture_task", title: "Email the accountant #admin")

      expect(content).to include("title" => "Email the accountant #admin", "tags" => [])
    end

    it "refuses a tag that is not a lowercase word" do
      call_tool("capture_task", title: "Email the accountant", tags: ["not_a_tag"])

      expect(message).to eq("tags: tags are lowercase words")
    end

    it "captures a task into today's sprint" do
      call_tool("capture_task", title: "Ship it", list: "today")

      expect(content.fetch("sprint_on")).to eq(today.iso8601)
    end

    it "schedules a task for a later sprint" do
      call_tool("capture_task", title: "Later", sprint_on: (today + 3).iso8601)

      expect(content.fetch("sprint_on")).to eq((today + 3).iso8601)
    end

    it "refuses a title with nothing in it, as the admin does" do
      call_tool("capture_task", title: "  ")

      expect(message).to eq("title: write the task down first")
    end

    it "refuses a sprint day in the past, as the admin does" do
      call_tool("capture_task", title: "Too late", sprint_on: (today - 1).iso8601)

      expect(message).to eq("a sprint opens on today or a day after it")
    end

    it "captures nothing when it refuses the sprint day" do
      call_tool("capture_task", title: "Too late", sprint_on: (today - 1).iso8601)

      expect(tasks.all_open).to be_empty
    end

    it "captures nothing for a sprint day it cannot read" do
      call_tool("capture_task", title: "Someday", sprint_on: "next week")

      expect(tasks.all_open).to be_empty
    end
  end

  describe "save_task" do
    let(:task) { create(:task, title: "Draft", note: "the plan", tags: %w[admin]) }

    it "keeps every field it leaves out" do
      call_tool("save_task", id: task.id, title: "Final")

      expect(content).to include("title" => "Final", "note" => "the plan", "tags" => %w[admin])
    end

    it "replaces the whole set of tags" do
      call_tool("save_task", id: task.id, tags: %w[site ruby])

      expect(tasks.by_id(task.id).tags.map(&:name)).to contain_exactly("site", "ruby")
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

    it "schedules the task for a later sprint" do
      call_tool("save_task", id: task.id, sprint_on: (today + 2).iso8601)

      expect(content.fetch("sprint_on")).to eq((today + 2).iso8601)
    end

    it "leaves the task alone when it refuses the sprint day" do
      call_tool("save_task", id: task.id, title: "Final", sprint_on: (today - 1).iso8601)

      expect(tasks.by_id(task.id).title).to eq("Draft")
    end

    it "leaves the task alone for a sprint day it cannot read" do
      call_tool("save_task", id: task.id, title: "Final", sprint_on: "next week")

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

    it "reopens a canceled task" do
      task = create(:task, :canceled)
      call_tool("reopen_task", id: task.id)

      expect(content).to include("status" => "open", "completed_at" => nil)
    end

    { "open" => [], "in_progress" => [:in_progress] }.each do |status, traits|
      it "cancels a task that is #{status}", :aggregate_failures do
        task = create(:task, *traits)
        call_tool("cancel_task", id: task.id)

        expect(content.fetch("status")).to eq("canceled")
        expect(content.fetch("completed_at")).not_to be_nil
      end
    end

    %i[done canceled].each do |status|
      it "refuses to cancel a task that is #{status}", :aggregate_failures do
        task = create(:task, status, completed_at: at(today - 1))
        call_tool("cancel_task", id: task.id)

        expect(message).to eq("task #{task.id} is already done or canceled")
        expect(tasks.by_id(task.id)).to have_attributes(status: status.to_s, completed_at: at(today - 1))
      end
    end

    %w[start_task complete_task reopen_task cancel_task delete_task].each do |name|
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

    it "answers with a task in progress open in its new list" do
      task = create(:task, :in_progress, :in_sprint, sprint_id: create(:sprint, sprint_date: today).id)
      call_tool("move_task", id: task.id, list: "someday")

      expect(content).to include("list" => "someday", "status" => "open")
    end
  end

  describe "reorder_task" do
    let!(:first) { create(:task, title: "first", position: 1) }
    let!(:second) { create(:task, title: "second", position: 2) }

    it "moves a task past the one above it" do
      call_tool("reorder_task", id: second.id, direction: "up")

      expect(tasks.in_list("next").map(&:title)).to eq(%w[second first])
    end

    it "moves a task past one that shares its position" do
      tied = create(:task, title: "tied", position: 2)
      call_tool("reorder_task", id: tied.id, direction: "up")

      expect(tasks.in_list("next").map(&:title)).to eq(%w[first tied second])
    end

    it "moves a task down past the one below it" do
      call_tool("reorder_task", id: first.id, direction: "down")

      expect(tasks.in_list("next").map(&:title)).to eq(%w[second first])
    end

    it "says it did not move a task already at the top" do
      call_tool("reorder_task", id: first.id, direction: "up")

      expect(content.fetch("moved")).to be(false)
    end

    {
      "a finished task" => :done,
      "a canceled task" => :canceled,
    }.each do |kind, trait|
      it "leaves #{kind} where it is", :aggregate_failures do
        closed = create(:task, trait, title: "closed", position: 3)
        call_tool("reorder_task", id: closed.id, direction: "up")

        expect(content.fetch("moved")).to be(false)
        expect(tasks.in_list("next").map(&:title)).to eq(%w[first second closed])
      end
    end

    it "moves a task past the one beside it in a sprint" do
      sprint = create(:sprint, sprint_date: today)
      create(:task, :in_sprint, sprint_id: sprint.id, title: "sprint one", position: 3)
      later = create(:task, :in_sprint, sprint_id: sprint.id, title: "sprint two", position: 4)
      call_tool("reorder_task", id: later.id, direction: "up")

      expect(tasks.in_sprint(sprint.id).map(&:title)).to eq(["sprint two", "sprint one"])
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

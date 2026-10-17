# frozen_string_literal: true

RSpec.describe "MCP task tools", type: :request do
  def mcp_scopes = %w[read write publish delete]

  it "refuses a list_tasks list it does not know as an error" do
    mcp_call("list_tasks", lists: %w[nowhere])

    expect(mcp_refused?).to be(true)
  end

  it "lists the tasks planned into a sprint day with the total that match" do
    sprint = create(:sprint, sprint_date: Blog::TimeZone.today + 2)
    task = create(:task, :in_sprint, sprint_id: sprint.id)
    create(:task)
    mcp_call("list_tasks", sprint_on: sprint.sprint_date.iso8601)

    expect(JSON.parse(mcp_message)).to include("total" => 1, "tasks" => [include("id" => task.id)])
  end

  it "lists only the tasks that list the owner, default included" do
    mine = create(:task)
    create(:task_contributor, task_id: create(:task).id)
    mcp_call("list_tasks", contributor: "owner")

    expect(JSON.parse(mcp_message)).to include("total" => 1, "tasks" => [include("id" => mine.id)])
  end

  it "finds the task a label names with list_tasks" do
    task = create(:task, title: "Record the intro", project_id: create(:project, name: "Podcast").id)
    create(:task, title: "Mow the lawn")
    mcp_call("list_tasks", query: "POD-1")

    expect(JSON.parse(mcp_message)).to include("total" => 1, "tasks" => [include("id" => task.id)])
  end

  describe "a column change" do
    def first_task = Tasks::Slice["relations.tasks"].in_order.pluck(:id).first

    before { create(:task, :in_progress) }

    it "puts a task stage_task moves first" do
      task = create(:task)
      mcp_call("stage_task", id: task.id, stage: "ready")

      expect(first_task).to eq(task.id)
    end

    it "puts a task pause_task moves first" do
      task = create(:task, :in_progress)
      mcp_call("pause_task", id: task.id)

      expect(first_task).to eq(task.id)
    end

    it "puts a task start_task moves first" do
      task = create(:task)
      mcp_call("start_task", id: task.id)

      expect(first_task).to eq(task.id)
    end

    it "keeps the place of a task start_task finds running" do
      task = create(:task, :in_progress)
      mcp_call("start_task", id: task.id)

      expect(first_task).not_to eq(task.id)
    end

    it "keeps the place of a task stage_task leaves in its stage" do
      task = create(:task)
      mcp_call("stage_task", id: task.id, stage: "backlog")

      expect(first_task).not_to eq(task.id)
    end
  end

  describe "capture_task with a note" do
    let(:photo) { create(:photo) }
    let(:note) { "![The gutter](/media/#{photo.key})" }

    def task = Tasks::Slice["relations.tasks"].to_a.first

    before { mcp_call("capture_task", title: "Fix the gutter", note:) }

    it "stores the note on the new task" do
      expect(task[:note]).to eq(note)
    end

    it "claims the photo in the note for the new task" do
      claims = Media::Slice["relations.photo_claims"].where(owner: "task").to_a

      expect(claims.map { [it[:owner_id], it[:photo_id]] }).to eq([[task[:id], photo.id]])
    end
  end

  describe "capture_task in a project" do
    before { create(:project, name: "Podcast", key: "POD") }

    it "numbers the task in the project its key names" do
      mcp_call("capture_task", title: "Record the intro", project: "POD")

      expect(JSON.parse(mcp_message).fetch("label")).to eq("POD-1")
    end

    it "refuses a key no project has as an error and captures nothing" do
      mcp_call("capture_task", title: "Record the intro", project: "NOPE")

      expect([mcp_refused?, Tasks::Slice["relations.tasks"].count]).to eq([true, 0])
    end
  end

  %w[start_task complete_task reopen_task cancel_task delete_task].each do |name|
    it "refuses #{name} on a task that is not there as an error", :aggregate_failures do
      mcp_call(name, id: 999_999)

      expect(mcp_refused?).to be(true)
      expect(mcp_message).to eq("no task has the ID 999999")
    end
  end

  describe "recurrence" do
    def answer = JSON.parse(mcp_message)

    def series = Tasks::Slice["relations.task_series"]

    it "captures a task on a cadence" do
      mcp_call("capture_task", title: "Pay rent", recur: { cadence: "month_day", day: 1 })

      expect(answer.fetch("recur")).to include("cadence" => "month_day", "day" => 1, "paused" => false)
    end

    it "changes and clears a cadence with save_task", :aggregate_failures do
      task = create(:task)
      mcp_call("save_task", id: task.id, recur: { cadence: "yearly", month: 3, day: 14 })
      expect(answer.fetch("recur")).to include("cadence" => "yearly", "month" => 3, "day" => 14)

      mcp_call("save_task", id: task.id, recur: nil)
      expect([answer.fetch("recur"), series.count]).to eq([nil, 0])
    end

    it "refuses a cadence on an imported task as an error" do
      task = create(:task_source, task: create(:task, :external)).task
      mcp_call("save_task", id: task.id, recur: { cadence: "month_end" })

      expect([mcp_refused?, series.count]).to eq([true, 0])
    end

    it "shows a task's cadence when read_task reads it" do
      task = create(:task)
      Tasks::Slice["operations.set_task_cadence"].call(task.id, { cadence: "days", every: 4 })
      mcp_call("read_task", id: task.id)

      expect(answer.fetch("recur")).to include("cadence" => "days", "every" => 4)
    end

    describe "a series" do
      let(:task) { create(:task, title: "Water the plants") }
      let(:id) { Tasks::Slice["operations.set_task_cadence"].call(task.id, { cadence: "days", every: 2 }).value!.id }

      it "lists it with its current copy" do
        id
        mcp_call("list_task_series")

        expect(answer.fetch("task_series")).to match([include("id" => id, "task" => include("id" => task.id))])
      end

      it "pauses and resumes it", :aggregate_failures do
        mcp_call("pause_task_series", id:)
        expect(answer.fetch("paused")).to be(true)

        mcp_call("resume_task_series", id:)
        expect(answer.fetch("paused")).to be(false)
      end
    end
  end
end

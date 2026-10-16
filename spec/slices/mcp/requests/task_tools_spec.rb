# frozen_string_literal: true

RSpec.describe "MCP task tools", type: :request do
  def access_token
    @access_token ||= mcp_connect(
      create(:oauth_client), verifier: Blog::Types::NewSecret[], scope: "read write publish delete",
    ).fetch("access_token")
  end

  def call_tool(name, **arguments)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}" }
    body = { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name:, arguments: } }
    post "/mcp", JSON.generate(body), headers
  end

  def message = result.fetch("content").first.fetch("text")

  def refused? = result["isError"] == true

  def result = JSON.parse(last_response.body).fetch("result")

  it "refuses a list_tasks list it does not know as an error" do
    call_tool("list_tasks", lists: %w[nowhere])

    expect(refused?).to be(true)
  end

  it "lists the tasks planned into a sprint day with the total that match" do
    sprint = create(:sprint, sprint_date: Blog::TimeZone.today + 2)
    task = create(:task, :in_sprint, sprint_id: sprint.id)
    create(:task)
    call_tool("list_tasks", sprint_on: sprint.sprint_date.iso8601)

    expect(JSON.parse(message)).to include("total" => 1, "tasks" => [include("id" => task.id)])
  end

  it "lists only the tasks that list the owner, default included" do
    mine = create(:task)
    create(:task_contributor, task_id: create(:task).id)
    call_tool("list_tasks", contributor: "owner")

    expect(JSON.parse(message)).to include("total" => 1, "tasks" => [include("id" => mine.id)])
  end

  it "finds the task a label names with list_tasks" do
    task = create(:task, title: "Record the intro", project_id: create(:project, name: "Podcast").id)
    create(:task, title: "Mow the lawn")
    call_tool("list_tasks", query: "POD-1")

    expect(JSON.parse(message)).to include("total" => 1, "tasks" => [include("id" => task.id)])
  end

  describe "a column change" do
    def first_task = Tasks::Slice["relations.tasks"].in_order.pluck(:id).first

    before { create(:task, :in_progress) }

    it "puts a task stage_task moves first" do
      task = create(:task)
      call_tool("stage_task", id: task.id, stage: "ready")

      expect(first_task).to eq(task.id)
    end

    it "puts a task pause_task moves first" do
      task = create(:task, :in_progress)
      call_tool("pause_task", id: task.id)

      expect(first_task).to eq(task.id)
    end

    it "puts a task start_task moves first" do
      task = create(:task)
      call_tool("start_task", id: task.id)

      expect(first_task).to eq(task.id)
    end

    it "keeps the place of a task start_task finds running" do
      task = create(:task, :in_progress)
      call_tool("start_task", id: task.id)

      expect(first_task).not_to eq(task.id)
    end

    it "keeps the place of a task stage_task leaves in its stage" do
      task = create(:task)
      call_tool("stage_task", id: task.id, stage: "backlog")

      expect(first_task).not_to eq(task.id)
    end
  end

  describe "capture_task with a note" do
    let(:photo) { create(:photo) }
    let(:note) { "![The gutter](/media/#{photo.key})" }

    def task = Tasks::Slice["relations.tasks"].to_a.first

    before { call_tool("capture_task", title: "Fix the gutter", note:) }

    it "stores the note on the new task" do
      expect(task[:note]).to eq(note)
    end

    it "claims the photo in the note for the new task" do
      claims = Media::Slice["relations.photo_claims"].where(owner: "task").to_a

      expect(claims.map { [it[:owner_id], it[:photo_id]] }).to eq([[task[:id], photo.id]])
    end
  end

  %w[start_task complete_task reopen_task cancel_task delete_task].each do |name|
    it "refuses #{name} on a task that is not there as an error", :aggregate_failures do
      call_tool(name, id: 999_999)

      expect(refused?).to be(true)
      expect(message).to eq("no task has the ID 999999")
    end
  end

  describe "recurrence" do
    def answer = JSON.parse(message)

    def series = Tasks::Slice["relations.task_series"]

    it "captures a task on a cadence" do
      call_tool("capture_task", title: "Pay rent", recur: { cadence: "month_day", day: 1 })

      expect(answer.fetch("recur")).to include("cadence" => "month_day", "day" => 1, "paused" => false)
    end

    it "changes and clears a cadence with save_task", :aggregate_failures do
      task = create(:task)
      call_tool("save_task", id: task.id, recur: { cadence: "yearly", month: 3, day: 14 })
      expect(answer.fetch("recur")).to include("cadence" => "yearly", "month" => 3, "day" => 14)

      call_tool("save_task", id: task.id, recur: nil)
      expect([answer.fetch("recur"), series.count]).to eq([nil, 0])
    end

    it "refuses a cadence on an imported task as an error" do
      task = create(:task_source, task: create(:task, :external)).task
      call_tool("save_task", id: task.id, recur: { cadence: "month_end" })

      expect([refused?, series.count]).to eq([true, 0])
    end

    it "shows a task's cadence when read_task reads it" do
      task = create(:task)
      Tasks::Slice["operations.set_task_cadence"].call(task.id, { cadence: "days", every: 4 })
      call_tool("read_task", id: task.id)

      expect(answer.fetch("recur")).to include("cadence" => "days", "every" => 4)
    end

    describe "a series" do
      let(:task) { create(:task, title: "Water the plants") }
      let(:id) { Tasks::Slice["operations.set_task_cadence"].call(task.id, { cadence: "days", every: 2 }).value!.id }

      it "lists it with its current copy" do
        id
        call_tool("list_task_series")

        expect(answer.fetch("task_series")).to match([include("id" => id, "task" => include("id" => task.id))])
      end

      it "pauses and resumes it", :aggregate_failures do
        call_tool("pause_task_series", id:)
        expect(answer.fetch("paused")).to be(true)

        call_tool("resume_task_series", id:)
        expect(answer.fetch("paused")).to be(false)
      end
    end
  end
end

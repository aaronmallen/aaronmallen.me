# frozen_string_literal: true

RSpec.describe "API bulk task actions", type: :request do
  def act(name, ids, **fields) = call_api(name, JSON.generate(ids:, **fields))

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def bare(answer) = answer.fetch("tasks").map { it.except("id", "completed_at", "created_at", "updated_at") }

  def call_api(name, body)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    post "/api/v1/tasks/bulk/#{name}", body, headers
    JSON.parse(last_response.body)
  end

  def deleted(task) = { "id" => task.id, "title" => task.title, "deleted" => true }

  def gone_id = create(:task).id.tap { repo.delete(it) }

  def ids(tasks) = tasks.map(&:id)

  def missing(id) = "no task has the ID #{id}"

  def place(task) = repo.by_id(task.id).place

  def refusal(message) = { "error" => "invalid", "message" => message, "errors" => { "ids" => [message] } }

  def repo = Tasks::Slice["repos.task_repo"]

  def status = last_response.status

  def status_of(task) = repo.by_id(task.id)&.status

  def tag_names(task) = Tasks::Slice["relations.task_tags"].names_by_task([task.id]).fetch(task.id, [])

  def tagged(*names) = create(:task).tap { repo.replace_tags(it.id, names) }

  def tasks(count) = Array.new(count) { create(:task) }

  {
    "complete" => "done",
    "cancel" => "canceled",
  }.each do |name, changed|
    describe "POST /api/v1/tasks/bulk/#{name}" do
      let!(:picked) { tasks(2) }
      let!(:left) { create(:task) }

      it "changes the tasks it names and answers them" do
        answer = act(name, ids(picked))

        expect([answer.fetch("tasks").map { it.values_at("id", "status") }, status])
          .to eq([ids(picked).map { [it, changed] }, 200])
      end

      it "leaves the rest alone" do
        act(name, ids(picked))

        expect(status_of(left)).to eq("open")
      end

      it "changes none when one ID is gone and names it" do
        gone = gone_id

        expect([act(name, [*ids(picked), gone]), status, picked.map { status_of(it) }])
          .to eq([refusal(missing(gone)), 422, %w[open open]])
      end
    end
  end

  describe "POST /api/v1/tasks/bulk/cancel on a closed task" do
    it "cancels none and says which one was closed" do
      open_task = create(:task)
      done = create(:task, :done)
      answer = act("cancel", [open_task.id, done.id])

      expect([answer.fetch("errors"), status, status_of(open_task)])
        .to eq([{ "ids" => ["task #{done.id} is already done or canceled"] }, 422, "open"])
    end
  end

  describe "POST /api/v1/tasks/bulk/complete on a closed task" do
    let(:closed_at) { Time.now.round - 86_400 }
    let!(:open_task) { create(:task) }
    let!(:canceled) { create(:task, :canceled, completed_at: closed_at) }
    let!(:answer) { act("complete", [open_task.id, canceled.id]) }

    it "completes none and says which one was closed" do
      expect([answer.fetch("errors"), status, status_of(open_task)])
        .to eq([{ "ids" => ["task #{canceled.id} is already done or canceled"] }, 422, "open"])
    end

    it "leaves the closed task as it was" do
      expect(repo.by_id(canceled.id)).to have_attributes(status: "canceled", completed_at: closed_at)
    end
  end

  describe "POST /api/v1/tasks/bulk/delete" do
    let!(:picked) { [create(:task, title: "One"), create(:task, title: "Two")] }
    let!(:left) { create(:task) }

    it "deletes the tasks it names and answers them" do
      answer = act("delete", ids(picked))

      expect([answer, picked.map { status_of(it) }]).to eq([{ "tasks" => picked.map { deleted(it) } }, [nil, nil]])
    end

    it "leaves the rest alone" do
      act("delete", ids(picked))

      expect(status_of(left)).to eq("open")
    end

    it "deletes none when one ID is gone" do
      act("delete", [*ids(picked), gone_id])

      expect([status, picked.map { status_of(it) }]).to eq([422, %w[open open]])
    end
  end

  describe "POST /api/v1/tasks/bulk/move" do
    let!(:picked) { tasks(2) }

    it "moves the tasks to the list it names" do
      answer = act("move", ids(picked), list: "someday")

      expect([answer.fetch("tasks").map { it.fetch("list") }, picked.map { place(it) }])
        .to eq([%w[someday someday], %w[someday someday]])
    end

    it "moves the tasks into today's sprint" do
      answer = act("move", ids(picked), list: "today")

      expect(answer.fetch("tasks").map { it.fetch("sprint_on") }).to eq([Blog::TimeZone.today.iso8601] * 2)
    end

    it "moves none when one ID is gone" do
      act("move", [*ids(picked), gone_id], list: "someday")

      expect([status, picked.map { place(it) }]).to eq([422, %w[next next]])
    end

    it "refuses a list it does not know" do
      expect([act("move", ids(picked), list: "nowhere").fetch("errors").keys, status]).to eq([%w[list], 422])
    end

    it "refuses a request with no list" do
      expect(act("move", ids(picked)).fetch("errors")).to eq("list" => ["list is missing"])
    end
  end

  describe "POST /api/v1/tasks/bulk/tag" do
    let!(:picked) { [tagged("ruby"), tagged] }

    it "adds the tag to each task and keeps the ones it had" do
      answer = act("tag", ids(picked), tag: "Release")

      expect(answer.fetch("tasks").map { it.fetch("tags") }).to eq([%w[release ruby], %w[release]])
    end

    it "tags none when one ID is gone" do
      act("tag", [*ids(picked), gone_id], tag: "release")

      expect([status, picked.map { tag_names(it) }]).to eq([422, [%w[ruby], []]])
    end

    it "refuses a tag that is not lowercase words" do
      answer = act("tag", ids(picked), tag: "two words")

      expect([answer.fetch("errors"), status]).to eq([{ "tag" => ["a tag is lowercase words"] }, 422])
    end

    it "refuses a blank tag" do
      expect(act("tag", ids(picked), tag: " ").fetch("message")).to eq("tag: name the tag first")
    end
  end

  describe "POST /api/v1/tasks/bulk/untag" do
    let!(:picked) { [tagged("ruby", "rails"), tagged("ruby")] }

    it "takes the tag off each task" do
      answer = act("untag", ids(picked), tag: "ruby")

      expect(answer.fetch("tasks").map { it.fetch("tags") }).to eq([%w[rails], []])
    end

    it "untags none when one ID is gone" do
      act("untag", [*ids(picked), gone_id], tag: "ruby")

      expect(picked.map { tag_names(it) }).to eq([%w[rails ruby], %w[ruby]])
    end
  end

  describe "the list of IDs" do
    it "acts on a repeated ID once" do
      task = create(:task)

      expect(act("complete", [task.id, task.id]).fetch("tasks").map { it.fetch("id") }).to eq([task.id])
    end

    it "refuses an empty list" do
      expect([act("complete", []).fetch("errors").keys, status]).to eq([%w[ids], 422])
    end

    it "refuses more than 100 IDs" do
      expect([act("complete", (1..101).to_a).fetch("errors").keys, status]).to eq([%w[ids], 422])
    end

    it "refuses an ID that is not a number" do
      expect([act("complete", ["one"]).fetch("errors").keys, status]).to eq([%w[ids], 422])
    end

    it "refuses a request with no IDs" do
      expect(call_api("complete", "{}").fetch("errors")).to eq("ids" => ["ids is missing"])
    end
  end

  it "answers a failure it did not expect with a 500 that names the task" do
    task = create(:task)
    failing = instance_double(Tasks::Operations::ActOnTasks, call: Dry::Monads::Failure[:record, task.id, :unexpected])
    replace_component("tasks.operations.act_on_tasks", failing)

    expect([act("complete", [task.id]), status])
      .to eq([{ "error" => "failed", "message" => "could not change task #{task.id}" }, 500])
  end

  describe "the MCP tools" do
    %w[complete cancel].each do |name|
      it "#{name} as #{name}_tasks does" do
        first = create(:task, title: "same")
        last = create(:task, title: "same")

        expect(bare(mcp_answer("#{name}_tasks", ids: [last.id]))).to eq(bare(act(name, [first.id])))
      end
    end

    it "move as move_tasks does" do
      task = create(:task)
      moved = act("move", [task.id], list: "external")

      expect(unstamped(mcp_answer("move_tasks", ids: [task.id], list: "external"))).to eq(unstamped(moved))
    end

    it "tag as tag_tasks does" do
      task = create(:task)
      tagged_answer = act("tag", [task.id], tag: "ruby")

      expect(unstamped(mcp_answer("tag_tasks", ids: [task.id], tag: "ruby"))).to eq(unstamped(tagged_answer))
    end

    it "untag as untag_tasks does" do
      task = tagged("ruby", "rails")
      untagged = act("untag", [task.id], tag: "ruby")

      expect(unstamped(mcp_answer("untag_tasks", ids: [task.id], tag: "ruby"))).to eq(unstamped(untagged))
    end

    it "delete as delete_tasks does" do
      first = create(:task, title: "same")
      last = create(:task, title: "same")
      deleted = act("delete", [first.id])

      expect(mcp_answer("delete_tasks", ids: [last.id]))
        .to eq("tasks" => deleted.fetch("tasks").map { it.merge("id" => last.id) })
    end

    it "refuse a gone ID with the message the endpoint gives" do
      gone = gone_id
      refused = act("complete", [gone])

      expect(mcp_text("complete_tasks", ids: [gone])).to eq(refused.fetch("message"))
    end
  end
end

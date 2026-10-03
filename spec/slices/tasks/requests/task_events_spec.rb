# frozen_string_literal: true

RSpec.describe "Task events", type: :request do
  let(:today) { Blog::TimeZone.today }
  let(:at) { Time.at(Time.now.to_i - 600) }

  def events(task, *columns)
    found = Tasks::Slice["relations.task_events"].for_task(task.id).in_order.to_a

    found.map { it.to_h.slice(:kind, *columns) }
  end

  def moved(from_list: nil, from_sprint_on: nil, to_list: nil, to_sprint_on: nil)
    { kind: "moved", from_list:, from_sprint_on:, to_list:, to_sprint_on: }
  end

  def moves(task) = events(task, :from_list, :from_sprint_on, :to_list, :to_sprint_on).select { it[:kind] == "moved" }

  def operation(name) = Tasks::Slice["operations.#{name}"]

  def send_to(path, **params)
    post path, { _csrf_token: admin_csrf_token, **params }
  end

  def status(from, to) = { kind: "status_changed", from_status: from, to_status: to }

  def statuses(task) = events(task, :from_status, :to_status).select { it[:kind] == "status_changed" }

  def tag_changes(task) = events(task, :tag_name).select { it[:kind].end_with?("tagged") }

  before { sign_in_to_admin }

  describe "moving a task between lists" do
    it "records the from and to list" do
      task = create(:task)
      send_to("/admin/tasks/#{task.id}/move/someday")

      expect(moves(task)).to eq([moved(from_list: "next", to_list: "someday")])
    end

    it "stamps the event with the time of the move" do
      task = create(:task)
      operation(:move_task).call(task.id, "someday", at:)

      expect(events(task, :occurred_at)).to eq([{ kind: "moved", occurred_at: at }])
    end

    it "records nothing for a move to the list the task is already in" do
      task = create(:task)
      send_to("/admin/tasks/#{task.id}/move/next")

      expect(events(task)).to be_empty
    end
  end

  describe "moving a task into or out of Today" do
    it "records a move into Today" do
      task = create(:task)
      send_to("/admin/tasks/#{task.id}/move/today")

      expect(moves(task)).to eq([moved(from_list: "next", to_sprint_on: today)])
    end

    it "records a move out of Today" do
      task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today))
      send_to("/admin/tasks/#{task.id}/move/next")

      expect(moves(task)).to eq([moved(from_sprint_on: today, to_list: "next")])
    end

    it "records the pause when a task in progress leaves Today" do
      task = create(:task, :in_progress, :in_sprint, sprint: create(:sprint, sprint_date: today))
      send_to("/admin/tasks/#{task.id}/move/next")

      expect(statuses(task)).to eq([status("in_progress", "open")])
    end
  end

  describe "scheduling a task" do
    it "records a move into a later sprint" do
      task = create(:task)
      operation(:schedule_task).call(task.id, (today + 2).iso8601)

      expect(moves(task)).to eq([moved(from_list: "next", to_sprint_on: today + 2)])
    end

    it "records a move from Today into a later sprint" do
      task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today))
      operation(:schedule_task).call(task.id, (today + 2).iso8601)

      expect(moves(task)).to eq([moved(from_sprint_on: today, to_sprint_on: today + 2)])
    end

    it "records a move out of a sprint when the task is unscheduled" do
      task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today + 2))
      operation(:schedule_task).call(task.id, "")

      expect(moves(task)).to eq([moved(from_sprint_on: today + 2, to_list: "next")])
    end

    it "records a move into Today for a task scheduled for today" do
      task = create(:task)
      operation(:schedule_task).call(task.id, today.iso8601)

      expect(moves(task)).to eq([moved(from_list: "next", to_sprint_on: today)])
    end

    it "records the move when a task is captured for a later day" do
      _, task = operation(:capture_task).call({ title: "Plan it", note: "", tags: "" }, sprint_on: (today + 1).iso8601)
                                        .value!

      expect(moves(task)).to eq([moved(from_list: "next", to_sprint_on: today + 1)])
    end
  end

  describe "the midnight rollover" do
    it "records the move from yesterday's sprint into today's" do
      task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today - 1))
      Tasks::Jobs::RollOverSprint.new.perform

      expect(moves(task)).to eq([moved(from_sprint_on: today - 1, to_sprint_on: today)])
    end

    it "records no status change for a task it carries in progress" do
      task = create(:task, :in_progress, :in_sprint, sprint: create(:sprint, sprint_date: today - 1))
      Tasks::Jobs::RollOverSprint.new.perform

      expect(statuses(task)).to be_empty
    end

    it "records nothing for a finished task it leaves behind" do
      task = create(:task, :done, :in_sprint, sprint: create(:sprint, sprint_date: today - 1))
      Tasks::Jobs::RollOverSprint.new.perform

      expect(events(task)).to be_empty
    end
  end

  describe "dropping a sprint" do
    it "records the move back to a list" do
      task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today + 2))
      operation(:drop_sprint).call(task.sprint_id)

      expect(moves(task)).to eq([moved(from_sprint_on: today + 2, to_list: "next")])
    end

    it "keeps the record after the sprint is gone" do
      task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today + 2))
      send_to("/admin/tasks/sprints/#{task.sprint_id}/delete")

      expect(moves(task).map { it[:from_sprint_on] }).to eq([today + 2])
    end

    it "records the move of a synced task back to External" do
      task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today + 2))
      create(:task_source, task:)
      operation(:drop_sprint).call(task.sprint_id)

      expect(moves(task)).to eq([moved(from_sprint_on: today + 2, to_list: "external")])
    end
  end

  describe "tagging a task" do
    let(:fields) { { title: "Email the accountant", list: "", note: "" } }

    it "records each tag added on save" do
      task = create(:task)
      send_to("/admin/tasks/#{task.id}", filter: "next", task: { **fields, tags: "money, home" })

      expect(tag_changes(task)).to contain_exactly(
        { kind: "tagged", tag_name: "money" }, { kind: "tagged", tag_name: "home" },
      )
    end

    it "records a tag removed on save" do
      task = create(:task)
      operation(:save_task).call(task.id, { **fields, tags: "money, home" })
      operation(:save_task).call(task.id, { **fields, tags: "money" })

      expect(tag_changes(task).last).to eq({ kind: "untagged", tag_name: "home" })
    end

    it "records nothing when the tags stay the same" do
      task = create(:task)
      operation(:save_task).call(task.id, { **fields, tags: "money" })
      operation(:save_task).call(task.id, { **fields, tags: "money" })

      expect(tag_changes(task)).to eq([{ kind: "tagged", tag_name: "money" }])
    end

    it "records the tags a task is captured with" do
      _, task = operation(:capture_task).call({ title: "File taxes", note: "", tags: "money" }).value!

      expect(tag_changes(task)).to eq([{ kind: "tagged", tag_name: "money" }])
    end
  end

  describe "changing a task's status" do
    it "records a start" do
      task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today))
      send_to("/admin/tasks/#{task.id}/start")

      expect(statuses(task)).to eq([status("open", "in_progress")])
    end

    it "records the move into Today when a task in a list starts" do
      task = create(:task)
      operation(:start_task).call(task.id)

      expect(moves(task)).to eq([moved(from_list: "next", to_sprint_on: today)])
    end

    it "records a pause" do
      task = create(:task, :in_progress, :in_sprint, sprint: create(:sprint, sprint_date: today))
      send_to("/admin/tasks/#{task.id}/stop")

      expect(statuses(task)).to eq([status("in_progress", "open")])
    end

    it "records a complete" do
      task = create(:task, :in_progress)
      send_to("/admin/tasks/#{task.id}/complete")

      expect(statuses(task)).to eq([status("in_progress", "done")])
    end

    it "records a cancel" do
      task = create(:task)
      send_to("/admin/tasks/#{task.id}/cancel")

      expect(statuses(task)).to eq([status("open", "canceled")])
    end

    it "records a reopen" do
      task = create(:task, :done)
      send_to("/admin/tasks/#{task.id}/reopen")

      expect(statuses(task)).to eq([status("done", "open")])
    end

    it "stamps each event with the time of the change" do
      task = create(:task, :in_sprint, sprint: create(:sprint, sprint_date: today))
      operation(:start_task).call(task.id, at:)
      operation(:complete_task).call(task.id, at: at + 60)

      expect(events(task, :occurred_at).map { it[:occurred_at] }).to eq([at, at + 60])
    end
  end

  describe "deleting a task" do
    it "takes its events with it" do
      task = create(:task)
      send_to("/admin/tasks/#{task.id}/move/someday")
      send_to("/admin/tasks/#{task.id}/delete")

      expect(events(task)).to be_empty
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Marking a synced task seen", type: :request do
  let(:today) { Blog::TimeZone.today }
  let(:fields) { { title: "Sync my issues", list: "", note: "" } }

  def operation(name) = Tasks::Slice["operations.#{name}"]

  def seen_at(task) = Tasks::Slice["repos.task_repo"].by_id(task.id).source.seen_at

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def synced(*traits, **attributes)
    task = create(:task, *traits, list: "external", **attributes)
    create(:task_source, task:)
    task
  end

  before { sign_in_to_admin }

  it "leaves a new source unseen" do
    expect(seen_at(synced)).to be_nil
  end

  describe "moving a synced task" do
    it "marks it seen when it moves to another list" do
      task = synced
      send_to("/admin/tasks/#{task.id}/move/someday")

      expect(seen_at(task)).not_to be_nil
    end

    it "marks it seen when it moves into Today" do
      task = synced
      send_to("/admin/tasks/#{task.id}/move/today")

      expect(seen_at(task)).not_to be_nil
    end

    it "marks it seen when it is scheduled" do
      task = synced
      operation(:schedule_task).call(task.id, (today + 2).iso8601)

      expect(seen_at(task)).not_to be_nil
    end

    it "marks it seen when it starts from a list" do
      task = synced
      operation(:start_task).call(task.id)

      expect(seen_at(task)).not_to be_nil
    end

    it "leaves it unseen for a move to the list it is already in" do
      task = synced
      send_to("/admin/tasks/#{task.id}/move/external")

      expect(seen_at(task)).to be_nil
    end

    it "keeps the first time it was seen" do
      task = synced
      operation(:move_task).call(task.id, "someday", at: Time.at(Time.now.to_i - 600))
      first = seen_at(task)
      operation(:move_task).call(task.id, "next")

      expect(seen_at(task)).to eq(first)
    end
  end

  describe "changing a synced task's tags" do
    it "marks it seen when a tag is added" do
      task = synced
      send_to("/admin/tasks/#{task.id}", filter: "external", task: { **fields, tags: "work" })

      expect(seen_at(task)).not_to be_nil
    end

    it "leaves it unseen when a save keeps the tags" do
      task = synced
      operation(:save_task).call(task.id, { **fields, tags: "" })

      expect(seen_at(task)).to be_nil
    end
  end

  describe "a status change that keeps the task in place" do
    it "leaves it unseen" do
      task = synced
      operation(:complete_task).call(task.id)

      expect(seen_at(task)).to be_nil
    end
  end

  describe "the mark-seen operation" do
    it "marks a synced task seen at the time it is given" do
      task = synced
      at = Time.at(Time.now.to_i - 600)
      operation(:mark_task_seen).call(task.id, at:)

      expect(seen_at(task)).to eq(at)
    end

    it "leaves the task where it is", :aggregate_failures do
      task = synced
      seen = operation(:mark_task_seen).call(task.id).value!

      expect(seen).to have_attributes(id: task.id, list: "external", sprint_id: nil)
      expect(Tasks::Slice["relations.task_events"].for_task(task.id).to_a).to be_empty
    end

    it "refuses a task with no source" do
      task = create(:task)

      expect(operation(:mark_task_seen).call(task.id).failure).to eq(:unsourced)
    end

    it "refuses a task that does not exist" do
      expect(operation(:mark_task_seen).call(0).failure).to eq(:not_found)
    end
  end
end

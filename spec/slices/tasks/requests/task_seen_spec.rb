# frozen_string_literal: true

RSpec.describe "Marking a synced task seen", type: :request do
  let(:today) { Blog::TimeZone.today }
  let(:fields) { { title: "Sync my issues", list: "", note: "" } }

  def seen_at(task) = Tasks::Slice["repos.task_queries"].by_id(task.id).source.seen_at

  def send_at(time, path, **)
    allow(Time).to receive(:now).and_return(time)
    send_to(path, **)
    allow(Time).to receive(:now).and_call_original
  end

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def synced(*traits, **attributes)
    task = create(:task, *traits, list: "external", **attributes)
    create(:task_source, task:)
    task
  end

  before { sign_in_to_admin }

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
      send_to("/admin/tasks/#{task.id}/schedule", sprint_on: (today + 2).iso8601)

      expect(seen_at(task)).not_to be_nil
    end

    it "marks it seen when it starts from a list" do
      task = synced
      send_to("/admin/tasks/#{task.id}/start")

      expect(seen_at(task)).not_to be_nil
    end

    it "leaves it unseen for a move to the list it is already in" do
      task = synced
      send_to("/admin/tasks/#{task.id}/move/external")

      expect(seen_at(task)).to be_nil
    end

    it "keeps the first time it was seen" do
      task = synced
      first = Time.at(Time.now.to_i - 600)
      send_at(first, "/admin/tasks/#{task.id}/move/someday")
      send_to("/admin/tasks/#{task.id}/move/next")

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
      send_to("/admin/tasks/#{task.id}", filter: "external", task: { **fields, tags: "" })

      expect(seen_at(task)).to be_nil
    end
  end

  describe "a status change that keeps the task in place" do
    it "leaves it unseen" do
      task = synced
      send_to("/admin/tasks/#{task.id}/complete")

      expect(seen_at(task)).to be_nil
    end
  end
end

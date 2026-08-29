# frozen_string_literal: true

RSpec.describe "Tasks", type: :request do
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:sprints) { Tasks::Slice["repos.sprint_repo"] }
  let(:today) { Blog::TimeZone.today }

  def send_to(path, **params)
    post path, { _csrf_token: admin_csrf_token, **params }
  end

  before { sign_in_to_admin }

  describe "capturing a task" do
    it "answers 422 for a form with no title field" do
      send_to("/admin/tasks", filter: "next", task: { task_type_id: "" })

      expect(last_response.status).to eq(422)
    end

    it "writes nothing for a form with no title field" do
      send_to("/admin/tasks", filter: "next", task: { task_type_id: "" })

      expect(repo.in_list("next")).to be_empty
    end

    it "leaves a task untyped when its type is gone" do
      send_to("/admin/tasks", filter: "next", task: { title: "Email the accountant", task_type_id: "999999" })

      expect(repo.in_list("next").map(&:task_type_id)).to eq([nil])
    end
  end

  describe "editing a task" do
    it "leaves a task untyped when its type is gone" do
      task = create(:task, task_type_id: create(:task_type).id)
      fields = { title: task.title, list: "", note: "", tags: "", task_type_id: "999999" }
      send_to("/admin/tasks/#{task.id}", filter: "next", task: fields)

      expect(repo.by_id(task.id).task_type_id).to be_nil
    end
  end

  describe "reordering a task in today's sprint" do
    let(:sprint) { create(:sprint, sprint_date: today) }

    def today_titles = repo.in_sprint(sprint.id).map(&:title)

    before do
      create(:task, :in_sprint, sprint_id: sprint.id, title: "first", position: 1)
      create(:task, :in_sprint, sprint_id: sprint.id, title: "second", position: 2)
    end

    it "moves it past the task beside it in the sprint" do
      send_to("/admin/tasks/#{repo.in_sprint(sprint.id).last.id}/reorder/up", filter: "today")

      expect(today_titles).to eq(%w[second first])
    end

    it "leaves a finished task where it is" do
      done = create(:task, :done, :in_sprint, sprint_id: sprint.id, title: "done", position: 3)
      send_to("/admin/tasks/#{done.id}/reorder/up", filter: "today")

      expect(today_titles).to eq(%w[first second done])
    end

    it "comes back to the list for a finished task rather than failing" do
      done = create(:task, :done, :in_sprint, sprint_id: sprint.id, position: 3)
      send_to("/admin/tasks/#{done.id}/reorder/up", filter: "today")

      expect(last_response).to be_redirect
    end
  end

  describe "scheduling a task in progress for a later day" do
    let(:task) { create(:task, :in_progress, :in_sprint, sprint_id: create(:sprint, sprint_date: today).id) }

    before { send_to("/admin/tasks/#{task.id}/schedule", sprint_on: (today + 2).iso8601) }

    it "puts it back to open while it waits" do
      expect(repo.by_id(task.id).status).to eq("open")
    end

    it "moves it onto that day's sprint" do
      expect(sprints.by_id(repo.by_id(task.id).sprint_id).sprint_date).to eq(today + 2)
    end
  end
end

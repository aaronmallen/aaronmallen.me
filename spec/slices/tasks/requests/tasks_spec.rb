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
      send_to("/admin/tasks", filter: "next", task: { note: "" })

      expect(last_response.status).to eq(422)
    end

    it "writes nothing for a form with no title field" do
      send_to("/admin/tasks", filter: "next", task: { note: "" })

      expect(repo.in_list("next")).to be_empty
    end

    it "ignores a type left over from an older form" do
      send_to("/admin/tasks", filter: "next", task: { title: "Email the accountant", task_type_id: "1" })

      expect(repo.in_list("next").map(&:title)).to eq(["Email the accountant"])
    end
  end

  describe "editing a task" do
    it "ignores a type left over from an older form" do
      task = create(:task)
      fields = { title: "Email the accountant", list: "", note: "", tags: "", task_type_id: "1" }
      send_to("/admin/tasks/#{task.id}", filter: "next", task: fields)

      expect(repo.by_id(task.id).title).to eq("Email the accountant")
    end
  end

  describe "canceling a task" do
    let(:cancel_task) { Tasks::Slice["operations.cancel_task"] }

    it "marks it canceled" do
      task = create(:task)
      cancel_task.call(task.id)

      expect(repo.by_id(task.id).status).to eq("canceled")
    end

    it "writes when it was closed" do
      task = create(:task, :in_progress)
      at = Time.now.round
      cancel_task.call(task.id, at:)

      expect(repo.by_id(task.id).completed_at).to eq(at)
    end

    it "refuses a task already done" do
      expect(cancel_task.call(create(:task, :done).id).failure).to eq(:closed)
    end

    it "refuses a task already canceled" do
      expect(cancel_task.call(create(:task, :canceled).id).failure).to eq(:closed)
    end

    it "refuses a task that isn't there" do
      expect(cancel_task.call(0).failure).to eq(:not_found)
    end

    it "leaves a done task done" do
      task = create(:task, :done)
      cancel_task.call(task.id)

      expect(repo.by_id(task.id).status).to eq("done")
    end

    it "is refused by Postgres without a close time" do
      expect { create(:task, status: "canceled") }.to raise_error(ROM::SQL::CheckConstraintError)
    end
  end

  describe "a task imported from GitHub" do
    let!(:source) { create(:task_source, remote_id: "I_kwDOAbc", url: "https://github.com/aaronmallen/blog/issues/7") }
    let(:task_by_id) { Tasks::Slice["queries.task_by_id"] }

    it "carries its source URL when read" do
      expect(task_by_id.call(source.task_id).source.url).to eq("https://github.com/aaronmallen/blog/issues/7")
    end

    it "carries no source when it was made by hand" do
      expect(task_by_id.call(create(:task).id).source).to be_nil
    end

    it "is found by its provider and its id there" do
      expect(repo.by_source("github", "I_kwDOAbc").id).to eq(source.task_id)
    end

    it "finds nothing for an issue that never imported" do
      expect(repo.by_source("github", "I_missing")).to be_nil
    end

    it "is refused by Postgres a second source for the same issue" do
      expect { create(:task_source, remote_id: source.remote_id) }.to raise_error(ROM::SQL::UniqueConstraintError)
    end

    it "loses its source when the task is deleted" do
      Tasks::Slice["operations.delete_task"].call(source.task_id)

      expect(Tasks::Slice["relations.task_sources"].where(id: source.id).count).to eq(0)
    end
  end

  describe "a task imported from Linear" do
    let!(:source) do
      url = "https://linear.app/acme/issue/ABC-123/fix-the-feed"
      create(:task_source, provider: "linear", remote_id: "lin_1", remote_state: "started", url:)
    end

    it "is found by its provider and its id there" do
      expect(repo.by_source("linear", "lin_1").id).to eq(source.task_id)
    end

    it "carries the started state it was saved with when read" do
      expect(Tasks::Slice["queries.task_by_id"].call(source.task_id).source.remote_state).to eq("started")
    end

    it "shares an id with a GitHub issue without a clash" do
      expect(create(:task_source, remote_id: "lin_1").provider).to eq("github")
    end
  end

  describe "opening a canceled task again" do
    let(:task) { create(:task, :canceled) }

    it "reopens it" do
      send_to("/admin/tasks/#{task.id}/reopen", filter: "completed")

      expect(repo.by_id(task.id).status).to eq("open")
    end

    it "clears the close time" do
      send_to("/admin/tasks/#{task.id}/reopen", filter: "completed")

      expect(repo.by_id(task.id).completed_at).to be_nil
    end

    it "clears the close time when it is started" do
      send_to("/admin/tasks/#{task.id}/start", filter: "completed")

      expect(repo.by_id(task.id)).to have_attributes(status: "in_progress", completed_at: nil)
    end
  end

  describe "a canceled task among the finished ones" do
    let(:page) { Capybara.string(last_response.body) }

    before do
      create(:task, :done, title: "Filed already")
      create(:task, :canceled, title: "Dropped")
    end

    it "lists it on the completed tab" do
      get "/admin/tasks", filter: "completed"

      expect(page.all(".task-title").map(&:text)).to contain_exactly("Filed already", "Dropped")
    end

    it "counts it on the completed tab" do
      get "/admin/tasks"

      expect(page.all(".subtab-count").map(&:text).last).to eq("2")
    end

    it "counts it as closed today in the page sub" do
      get "/admin/tasks"

      expect(page).to have_css(".page-head-sub", text: "2 finished today")
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

    it "leaves a canceled task where it is" do
      canceled = create(:task, :canceled, :in_sprint, sprint_id: sprint.id, title: "canceled", position: 3)
      send_to("/admin/tasks/#{canceled.id}/reorder/up", filter: "today")

      expect(today_titles).to eq(%w[first second canceled])
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

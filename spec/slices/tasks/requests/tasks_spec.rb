# frozen_string_literal: true

RSpec.describe "Tasks", :frozen_clock, type: :request do
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:sprints) { Tasks::Slice["repos.sprint_repo"] }
  let(:today) { Blog::TimeZone.today }

  def capture(title) = Tasks::Slice["operations.capture_task"].call({ title:, note: "", tags: "" })

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

  describe "placing a new task" do
    it "puts a captured task after the ones already in its list" do
      create(:task, title: "older", position: 1)
      create(:task, title: "old", position: 2)
      capture("new")

      expect(repo.in_list("next").map(&:title)).to eq(%w[older old new])
    end
  end

  describe "two tasks placed at once", :commits do
    let(:client) { Spec::IssueClient.new }

    def database = Tasks::Slice["db.rom"].gateways[:default].connection

    def held_by_another_session
      other = Sequel.connect(database.opts.merge(max_connections: 1))
      other.get(Sequel.function(:pg_advisory_lock, Sequel.function(:hashtext, "tasks")))
      yield
    ensure
      other&.disconnect
    end

    def import(id)
      url = "https://linear.app/acme/issue/#{id}"
      client.assigned << { body: "", id:, reference: id, remote_state: "open", title: id, url: }
      Tasks::Slice["operations.sync_issues"].call(provider: "linear", client:)
    end

    def placed_together(*writes)
      held_by_another_session do
        writes.map { Thread.new(&it) }.tap { wait_until_all_wait(writes.size) }
      end.each(&:join)
      Tasks::Slice["relations.tasks"].pluck(:position)
    end

    def wait_until_all_wait(count)
      here = database[:pg_database].where(datname: Sequel.function(:current_database)).select(:oid)
      waiting = database[:pg_locks].where(locktype: "advisory", granted: false, database: here)
      Timeout.timeout(5) { sleep(0.01) until waiting.count == count }
    end

    it "gives two captured tasks different positions" do
      positions = placed_together(-> { capture("one") }, -> { capture("two") })

      expect(positions.uniq.size).to eq(2)
    end

    it "gives a captured task and an imported one different positions" do
      positions = placed_together(-> { capture("one") }, -> { import("L_two") })

      expect(positions.uniq.size).to eq(2)
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

  describe "completing a closed task" do
    let(:complete_task) { Tasks::Slice["operations.complete_task"] }
    let(:closed_at) { Time.now.round - 86_400 }

    %i[done canceled].each do |status|
      it "refuses a task already #{status}" do
        expect(complete_task.call(create(:task, status).id).failure).to eq(:closed)
      end

      it "leaves a #{status} task as it was" do
        task = create(:task, status, completed_at: closed_at)
        complete_task.call(task.id)

        expect(repo.by_id(task.id)).to have_attributes(status: status.to_s, completed_at: closed_at)
      end

      it "tracks no event on a #{status} task" do
        task = create(:task, status)

        expect { complete_task.call(task.id) }
          .not_to(change { Tasks::Slice["relations.task_events"].for_task(task.id).count })
      end
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

  describe "placing a task in today's sprint" do
    let(:sprint) { create(:sprint, sprint_date: today) }

    def sprinted(title) = repo.in_sprint(sprint.id).find { it.title == title }

    def today_titles = repo.in_sprint(sprint.id).map(&:title)

    before do
      %w[first second third].each.with_index(1) do |title, position|
        create(:task, :in_sprint, sprint_id: sprint.id, title:, position:)
      end
    end

    it "puts it right after the task it follows" do
      send_to("/admin/tasks/#{sprinted('first').id}/place", after: sprinted("third").id)

      expect(today_titles).to eq(%w[second third first])
    end

    it "moves it to the top of the sprint with nothing to follow" do
      send_to("/admin/tasks/#{sprinted('third').id}/place")

      expect(today_titles).to eq(%w[third first second])
    end

    it "refuses to follow a task in another sprint with no change", :aggregate_failures do
      other = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: today + 1).id, position: 4)
      send_to("/admin/tasks/#{sprinted('first').id}/place", after: other.id)

      expect(last_response.status).to eq(422)
      expect(today_titles).to eq(%w[first second third])
    end

    it "refuses to follow a task in a list with no change", :aggregate_failures do
      send_to("/admin/tasks/#{sprinted('first').id}/place", after: create(:task, position: 4).id)

      expect(last_response.status).to eq(422)
      expect(today_titles).to eq(%w[first second third])
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

  closed_days = { "a later day" => 3, "today" => 0 }.freeze

  %i[done canceled].each do |status|
    describe "scheduling a #{status} task" do
      let(:closed) { create(:task, status, title: "Email the accountant", completed_at: Time.now - 60) }

      def edit(**fields) = send_to("/admin/tasks/#{closed.id}", filter: "next", task: { title: closed.title, **fields })

      def schedule(day) = send_to("/admin/tasks/#{closed.id}/schedule", sprint_on: day.to_s)

      def toast = Capybara.string(last_response.body).find("[data-toast] .toast", visible: :all).text(:all)

      closed_days.each do |named, ahead|
        it "leaves it #{status} in its list for #{named}" do
          schedule((today + ahead).iso8601)

          expect(repo.by_id(closed.id)).to have_attributes(status: status.to_s, sprint_id: nil, list: "next")
        end

        it "opens no sprint for #{named}" do
          schedule((today + ahead).iso8601)

          expect(sprints.on(today + ahead)).to be_nil
        end
      end

      it "says it is closed already" do
        schedule((today + 3).iso8601)
        follow_redirect!

        expect(toast).to eq("That task is closed already")
      end

      it "leaves it in the sprint it closed in when its date is cleared" do
        ran = create(:sprint, sprint_date: today - 1)
        task = create(:task, status, :in_sprint, sprint_id: ran.id, completed_at: Time.now - 60)
        send_to("/admin/tasks/#{task.id}/schedule", sprint_on: "")

        expect(repo.by_id(task.id)).to have_attributes(sprint_id: ran.id, list: nil)
      end

      it "keeps its title when its editor sends a new date" do
        edit(title: "Call the accountant", sprint_on: (today + 3).iso8601)

        expect(repo.by_id(closed.id)).to have_attributes(title: "Email the accountant", sprint_id: nil)
      end

      it "says it is closed already when its editor sends a new date" do
        edit(sprint_on: (today + 3).iso8601)
        follow_redirect!

        expect(toast).to eq("That task is closed already")
      end
    end
  end

  describe "moving a task in progress" do
    let(:task) { create(:task, :in_progress, :in_sprint, sprint_id: create(:sprint, sprint_date: today).id) }

    %w[next someday external].each do |list|
      it "leaves it open in #{list}" do
        send_to("/admin/tasks/#{task.id}/move/#{list}")

        expect(repo.by_id(task.id)).to have_attributes(list:, sprint_id: nil, status: "open")
      end
    end

    it "leaves it in progress when it goes to today" do
      listed = create(:task, :in_progress)
      send_to("/admin/tasks/#{listed.id}/move/today")

      expect(repo.by_id(listed.id)).to have_attributes(list: nil, status: "in_progress")
    end

    it "leaves a finished task finished" do
      done = create(:task, :done, :in_sprint, sprint_id: create(:sprint, sprint_date: today).id)
      send_to("/admin/tasks/#{done.id}/move/next")

      expect(repo.by_id(done.id).status).to eq("done")
    end
  end

  describe "unscheduling a task in progress" do
    let(:task) { create(:task, :in_progress, :in_sprint, sprint_id: create(:sprint, sprint_date: today).id) }

    it "leaves it open in next" do
      send_to("/admin/tasks/#{task.id}/schedule", sprint_on: "")

      expect(repo.by_id(task.id)).to have_attributes(list: "next", sprint_id: nil, status: "open")
    end
  end

  describe "dropping a sprint that holds a task in progress" do
    let(:sprint) { create(:sprint, sprint_date: today + 2) }

    def drop = send_to("/admin/tasks/sprints/#{sprint.id}/delete")

    it "leaves it open in next" do
      task = create(:task, :in_progress, :in_sprint, sprint_id: sprint.id)
      drop

      expect(repo.by_id(task.id)).to have_attributes(list: "next", sprint_id: nil, status: "open")
    end

    it "leaves a finished task finished" do
      done = create(:task, :done, :in_sprint, sprint_id: sprint.id)
      drop

      expect(repo.by_id(done.id)).to have_attributes(list: "next", status: "done")
    end
  end
end

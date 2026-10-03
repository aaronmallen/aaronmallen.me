# frozen_string_literal: true

RSpec.describe "Admin bulk task actions", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Tasks::Slice["repos.task_repo"] }

  def act(name, tasks, **params)
    ids = tasks.map { it.is_a?(Integer) ? it : it.id }
    post "/admin/tasks/bulk", { _csrf_token: admin_csrf_token, act: name, ids:, filter: "next", **params }
  end

  def gone_id = create(:task).id.tap { repo.delete(it) }

  def status(task) = repo.by_id(task.id)&.status

  def tasks(count) = Array.new(count) { create(:task) }

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the list" do
      before { tasks(2) }

      it "draws one bar that posts to the bulk route", :aggregate_failures do
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("form#task-bulk[action='/admin/tasks/bulk'][method='post']", count: 1)
        expect(page.all("form#task-bulk button[name='act']").map(&:value)).to eq(%w[complete cancel delete])
      end

      it "gives each row a box that joins the bar" do
        get "/admin/tasks", filter: "next"

        expect(page.all(".task input[type='checkbox'][name='ids[]'][form='task-bulk']").size).to eq(2)
      end

      it "names the task on each box" do
        task = create(:task, title: "Email the accountant")
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("input[value='#{task.id}'][aria-label='Select Email the accountant']")
      end

      it "shows the actions in the markup, so they work with scripts off" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("[data-bulk-acts]:not([hidden])")
      end

      it "leaves select all for the script to draw" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("[data-bulk-all][hidden]", visible: :all)
      end

      it "asks before deleting" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("button[value='delete'][data-confirm]")
      end

      it "keeps the search and the page in the bar", :aggregate_failures do
        lower_page_size(:admin, to: 1)
        get "/admin/tasks", filter: "next", page: 2, q: "a"

        expect(page).to have_css("form#task-bulk input[name='q'][value='a']", visible: :all)
        expect(page).to have_css("form#task-bulk input[name='page'][value='2']", visible: :all)
      end

      it "draws no bar on the archive" do
        create(:task, :done)
        get "/admin/tasks", filter: "completed"

        expect(page).to have_no_css("form#task-bulk")
      end
    end

    describe "an empty list" do
      it "draws no bar" do
        get "/admin/tasks", filter: "someday"

        expect(page).to have_no_css("form#task-bulk")
      end
    end

    {
      "complete" => ["done", "Finished 2 tasks"],
      "cancel" => ["canceled", "Canceled 2 tasks"],
    }.each do |name, (changed, said)|
      describe "#{name} on the ticked tasks" do
        let!(:ticked) { tasks(2) }
        let!(:left) { create(:task) }

        before { act(name, ticked) }

        it "changes them" do
          expect(ticked.map { status(it) }).to eq([changed, changed])
        end

        it "leaves the rest alone" do
          expect(status(left)).to eq("open")
        end

        it "says how many changed" do
          follow_redirect!

          expect(toast).to eq(said)
        end
      end
    end

    describe "delete on the ticked tasks" do
      let!(:ticked) { tasks(2) }
      let!(:left) { create(:task) }

      before { act("delete", ticked) }

      it "takes them away" do
        expect(ticked.map { status(it) }).to eq([nil, nil])
      end

      it "leaves the rest alone" do
        expect(status(left)).to eq("open")
      end

      it "says how many went" do
        follow_redirect!

        expect(toast).to eq("Deleted 2 tasks")
      end
    end

    describe "a batch with a task that is gone" do
      let!(:ticked) { tasks(2) }
      let(:missing) { gone_id }

      %w[complete cancel delete].each do |name|
        it "#{name} changes nothing" do
          act(name, [*ticked, missing])

          expect(ticked.map { status(it) }).to eq(%w[open open])
        end
      end

      it "names the task in the toast" do
        act("complete", [*ticked, missing])
        follow_redirect!

        expect(toast).to eq("Nothing changed · ##{missing} is gone")
      end
    end

    describe "a cancel that reaches a closed task" do
      let!(:ticked) { create(:task) }
      let!(:closed) { create(:task, :done, title: "Filed already") }

      before { act("cancel", [ticked, closed]) }

      it "changes nothing" do
        expect(status(ticked)).to eq("open")
      end

      it "names the task and why" do
        follow_redirect!

        expect(toast).to eq("Nothing changed · ##{closed.id} Filed already is closed already")
      end
    end

    describe "where it lands" do
      it "goes back to the list it came from" do
        act("complete", [create(:task, :someday)], filter: "someday")

        expect(last_response.headers["location"]).to eq("/admin/tasks?filter=someday")
      end

      it "keeps the search" do
        act("complete", [create(:task)], q: "tag:site")

        expect(last_response.headers["location"]).to eq("/admin/tasks?filter=next&q=tag:site")
      end

      it "keeps the page while it still has rows" do
        lower_page_size(:admin, to: 1)
        tasks(3)
        act("complete", [repo.in_list("next").last], page: 2)

        expect(last_response.headers["location"]).to eq("/admin/tasks?filter=next&page=2")
      end

      it "steps back a page when the batch emptied the last one" do
        lower_page_size(:admin, to: 1)
        tasks(2)
        act("complete", [repo.in_list("next").last], page: 2)

        expect(last_response.headers["location"]).to eq("/admin/tasks?filter=next")
      end

      it "goes back the same way after a failure" do
        act("complete", [gone_id], filter: "someday")

        expect(last_response.headers["location"]).to eq("/admin/tasks?filter=someday")
      end
    end

    describe "a refused batch" do
      it "asks for a tick when none came" do
        post "/admin/tasks/bulk", { _csrf_token: admin_csrf_token, act: "complete", filter: "next" }
        follow_redirect!

        expect(toast).to eq("Tick a task first")
      end

      it "refuses more than 100 tasks before it changes any", :aggregate_failures do
        tasks = tasks(101)
        act("complete", tasks)
        follow_redirect!

        expect(toast).to eq("Tick 100 tasks or fewer")
        expect(repo.in_list("next").size).to eq(101)
      end

      it "counts a repeated task once" do
        task = create(:task)
        act("complete", Array.new(101, task.id))
        follow_redirect!

        expect(toast).to eq("Finished 1 task")
      end

      it "refuses an action off the bar", :aggregate_failures do
        task = create(:task)
        act("archive", [task])
        follow_redirect!

        expect(toast).to eq("Nothing changed · pick an action from the bar")
        expect(status(task)).to eq("open")
      end
    end
  end

  describe "signed out" do
    it "changes nothing" do
      task = create(:task)
      post "/admin/tasks/bulk", { act: "complete", ids: [task.id] }

      expect(status(task)).to eq("open")
    end
  end
end

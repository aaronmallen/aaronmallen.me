# frozen_string_literal: true

RSpec.describe "Admin task row menu", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Tasks::Slice["repos.task_queries"] }
  let(:today) { Blog::TimeZone.today }
  let(:sprint) { create(:sprint, sprint_date: today) }

  def form(route) = page.first("form[action='#{route}']", visible: :all)

  def items = page.all(".ctx-label", visible: :all).map { it.text(:all) }

  def menu(task, **params) = get("/admin/tasks/#{task.id}/menu", params)

  def tag(task, *names) = Tasks::Slice["repos.task_mutations"].replace_tags(task.id, names)

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  describe "signed in" do
    before { sign_in_to_admin }

    it "answers 404 for a task that is gone" do
      get "/admin/tasks/0/menu"

      expect(last_response.status).to eq(404)
    end

    describe "an open task" do
      let(:task) { create(:task, title: "Ship it") }

      before do
        create(:tag, :private, name: "home")
        create(:tag, name: "ruby")
        tag(task, "home")
        menu(task, return_to: "/admin/tasks?filter=next", filter: "next", origin: "tasks")
      end

      it "draws the menu alone, headed by the task" do
        expect(page).to have_css("[data-context-menu] > .ctx-head", text: "#{task.number} · Ship it")
      end

      it "holds every action an open task takes", :aggregate_failures do
        expected = ["Open", "Start", "Complete", "Pull into today's sprint", "Move to", "Schedule", "Tags", "Copy",
                    "Cancel task", "Delete"]

        expect(items).to include(*expected)
        expect(items).not_to include("Reopen", "Pause", "Mark seen", "Open issue")
      end

      it "opens the task with the row's tab" do
        expect(page).to have_css("a.ctx-item[href='/admin/tasks/#{task.id}?filter=next&origin=tasks']")
      end

      it "posts every action by fetch and morph back to the page it opened on", :aggregate_failures do
        forms = page.all("[data-context-menu] form")

        expect(forms).to all(match_css("[data-morph]"))
        expect(forms.map { it.find("input[name=return_to]", visible: :all).value }.uniq)
          .to eq(["/admin/tasks?filter=next"])
      end

      it "lists only private tags, ticked when the task has them", :aggregate_failures do
        expect(page).to have_css("[role=menuitemcheckbox][aria-checked=true]", text: "#home", visible: :all)
        expect(page).to have_no_css("[role=menuitemcheckbox]", text: "#ruby", visible: :all)
      end

      it "unticks a tag through the bulk route" do
        fields = form("/admin/tasks/bulk").all("input", visible: :all).to_h { [it[:name], it.value] }

        expect(fields).to include("act" => "untag", "ids[]" => task.id.to_s, "tag" => "home")
      end

      it "asks before it deletes" do
        expect(page).to have_css("button[data-confirm-inline='#{translate('ui.views.tasks.menu.confirm_delete')}']")
      end

      it "disables the list the task is on" do
        expect(page).to have_css("button.ctx-item[disabled]", text: "Next", visible: :all)
      end
    end

    describe "a task on today's sprint" do
      it "disables Today" do
        menu(create(:task, :in_sprint, sprint_id: sprint.id))

        expect(page).to have_css("button.ctx-item[disabled]", text: "Today", visible: :all)
      end
    end

    describe "a task on a later sprint" do
      before { menu(create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: today + 1).id)) }

      it "lets it move to Today", :aggregate_failures do
        expect(page).to have_css("button.ctx-item:not([disabled])", text: "Today", visible: :all)
        expect(page).to have_no_css("button.ctx-item[disabled]", visible: :all)
      end
    end

    describe "a running task" do
      it "offers pause in place of start", :aggregate_failures do
        menu(create(:task, :in_sprint, :in_progress, sprint_id: sprint.id))

        expect(items).to include(translate("ui.views.tasks.menu.pause"))
        expect(items).not_to include(translate("ui.views.tasks.menu.start"))
      end

      it "leaves out the pull into today's sprint" do
        menu(create(:task, :in_sprint, sprint_id: sprint.id))

        expect(items).not_to include(translate("ui.components.tasks.menu_plan.pull"))
      end
    end

    describe "a closed task" do
      before { menu(create(:task, :done)) }

      it "offers reopen and nothing that needs it open", :aggregate_failures do
        expect(items).to include(translate("ui.views.tasks.menu.reopen"))
        expect(items).not_to include("Start", "Complete", "Cancel task", "Move to", "Schedule")
      end
    end

    describe "an external task from an issue" do
      let(:task) { create(:task, :external) }

      before do
        create(:task_source, task_id: task.id, url: "https://github.com/aaronmallen/aaronmallen.me/issues/7")
        menu(task)
      end

      it "opens and copies the issue and marks it seen", :aggregate_failures do
        expect(page).to have_css("a.ctx-item[href$='/issues/7'][target=_blank]")
        expect(page).to have_css("[data-copy$='/issues/7']", visible: :all)
        expect(page).to have_css("form[action='/admin/inbox/tasks/#{task.id}/seen']")
      end
    end

    describe "rows" do
      it "carry the menu on the tasks list" do
        task = create(:task)
        get "/admin/tasks", filter: "next"

        expect(page).to have_css(".task[data-menu='/admin/tasks/#{task.id}/menu?filter=next&origin=tasks']")
      end

      it "carry the menu in the sprint pool" do
        task = create(:task)
        get "/admin"

        expect(page).to have_css("[data-pools] .li[data-menu^='/admin/tasks/#{task.id}/menu']")
      end

      it "carry the menu in the calendar's day panel" do
        task = create(:task, :in_sprint, sprint_id: sprint.id)
        get "/admin/calendar", day: today.iso8601

        expect(page).to have_css("[data-calendar-panel] .li[data-menu='/admin/tasks/#{task.id}/menu']")
      end
    end

    describe "acting from the menu" do
      let(:task) { create(:task) }

      def act(path, **params) = post(path, { _csrf_token: admin_csrf_token, return_to: "/admin", **params })

      it "lands a move back on the page the menu opened on" do
        act("/admin/tasks/#{task.id}/move/someday")

        expect(last_response.location).to eq("/admin")
      end

      it "lands a tag back on the page the menu opened on", :aggregate_failures do
        act("/admin/tasks/bulk", act: "tag", ids: [task.id], tag: "home")

        expect(last_response.location).to eq("/admin")
        expect(repo.by_id(task.id).tags.map(&:name)).to eq(["home"])
      end

      it "refuses a bad tag name" do
        act("/admin/tasks/bulk", act: "tag", ids: [task.id], tag: "no good")
        follow_redirect!

        expect(toast).to eq(translate("tasks_page.toasts.bulk.invalid.tag_format"))
      end

      it "lands a seen issue back on the page the menu opened on" do
        external = create(:task, :external)
        create(:task_source, task_id: external.id)
        act("/admin/inbox/tasks/#{external.id}/seen")

        expect(last_response.location).to eq("/admin")
      end

      it "ignores a return path outside the admin" do
        act("/admin/tasks/#{task.id}/delete", return_to: "https://example.com/")

        expect(last_response.location).to start_with("/admin/tasks")
      end
    end
  end
end

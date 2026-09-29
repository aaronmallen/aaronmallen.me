# frozen_string_literal: true

RSpec.describe "Admin tasks", type: :feature do
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:sprint_repo) { Tasks::Slice["repos.sprint_repo"] }

  def move_to(list)
    named = translate(["ui.components.tasks.controls.lists", list].join("."))

    translate("ui.components.tasks.controls.move", list: named)
  end

  def open_editor(title) = find(".task", text: title).find(".task-title").click

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  before do
    create(:task, title: "Email the accountant")
    create(:task, :someday, title: "Learn Elixir")
    sign_in_to_admin
    visit "/admin/tasks?filter=next"
  end

  describe "the tabs" do
    before { find(".subtab", text: "someday").click }

    it "opens the list it names" do
      expect(page).to have_current_path("/admin/tasks?filter=someday")
    end

    it "lists only the someday tasks", :aggregate_failures do
      expect(page).to have_css(".task-title", text: "Learn Elixir")
      expect(page).to have_no_css(".task-title", text: "Email the accountant")
    end

    it "marks someday as the one you are on" do
      expect(page).to have_css(".subtab.on", text: "someday")
    end

    it "counts each list on its own tab" do
      expect(page.all(".subtab-count").map(&:text)).to eq(%w[0 0 1 1 0])
    end
  end

  describe "capturing a task" do
    before do
      fill_in("task[title]", with: "Call the plumber")
      find_field("task[title]").send_keys(:enter)
    end

    it "writes it down on Enter alone" do
      expect(page).to have_css(".task-title", text: "Call the plumber")
    end

    it "says so" do
      expect(page).to have_css("[data-toast]", text: "Task captured")
    end

    it "leaves the field ready for the next one" do
      expect(page).to have_css(".task-title", text: "Call the plumber").and have_field("task[title]", with: "")
    end
  end

  describe "searching" do
    let(:field) { translate("ui.components.tasks.filters.search") }

    before do
      create(:task, title: "Email the plumber")
      visit "/admin/tasks?filter=next"
      fill_in(field, with: "accountant")
      find_field(field).send_keys(:enter)
    end

    it "narrows the list it is on", :aggregate_failures do
      expect(page).to have_css(".task-title", text: "Email the accountant")
      expect(page).to have_no_css(".task-title", text: "Email the plumber")
    end

    it "keeps the query in the field" do
      expect(page).to have_field(field, with: "accountant")
    end

    it "carries the query onto the next tab" do
      find(".subtab", text: "someday").click

      expect(page).to have_field(field, with: "accountant")
    end
  end

  describe "the key" do
    let(:task) { repo.in_list("next").find { it.title == "Email the accountant" } }
    let(:key) { "##{task.id}" }

    def watch_clipboard
      page.execute_script(<<~JS)
        window.copiedKeys = [];
        Object.defineProperty(navigator, "clipboard", {
          value: { writeText: (text) => { window.copiedKeys.push(text); return Promise.resolve(); } },
        });
      JS
    end

    describe "clicking it" do
      before do
        watch_clipboard
        find(".task", text: "Email the accountant").find(".task-key").click
      end

      it "copies the key", :aggregate_failures do
        expect(page).to have_css(".toast", text: translate("ui.components.tasks.task_key.copied", key:))
        expect(page.evaluate_script("window.copiedKeys")).to eq([key])
      end
    end

    describe "with scripts off" do
      before do
        page.driver.browser.page.disable_javascript
        visit "/admin/tasks?filter=next"
      end

      after { page.driver.browser.page.command("Emulation.setScriptExecutionDisabled", value: false) }

      it "still shows the key" do
        expect(find(".task", text: "Email the accountant")).to have_css(".task-key", exact_text: key)
      end
    end
  end

  describe "moving a task to today" do
    before { find(".task", text: "Email the accountant").click_button(move_to("today")) }

    it "follows it to today", :aggregate_failures do
      expect(page).to have_current_path("/admin/tasks?filter=today")
      expect(page).to have_css(".task-title", text: "Email the accountant")
    end

    it "takes it off next" do
      find(".subtab", text: "next").click

      expect(page).to have_no_css(".task-title", text: "Email the accountant")
    end
  end

  describe "an empty sprint" do
    before { visit "/admin/tasks?filter=today" }

    it "asks what the day is for" do
      expect(page).to have_css(".task-planner .card-title", text: translate("ui.components.tasks.planner.ask"))
    end

    it "takes the answer into the sprint", :aggregate_failures do
      fill_in("task[title]", with: "Ship the screen")
      find_field("task[title]").send_keys(:enter)

      expect(page).to have_css(".task-title", text: "Ship the screen")
      expect(repo.in_sprint(sprint_repo.on(Blog::TimeZone.today).id).map(&:title)).to eq(["Ship the screen"])
    end

    it "drops the planner once the sprint holds a task" do
      fill_in("task[title]", with: "Ship the screen")
      find_field("task[title]").send_keys(:enter)

      expect(page).to have_css(".task-title", text: "Ship the screen").and have_no_css(".task-planner")
    end

    describe "switching the pool to someday" do
      before { find(".task-planner .seg-option", exact_text: "someday · 1").click }

      it "stays on the tasks screen" do
        expect(page).to have_current_path("/admin/tasks?filter=today&pool=someday")
      end

      it "offers what is in someday", :aggregate_failures do
        expect(page).to have_css(".task-planner .li-title", text: "Learn Elixir")
        expect(page).to have_no_css(".task-planner .li-title", text: "Email the accountant")
      end
    end

    describe "pulling from next" do
      before { find(".task-planner .li", text: "Email the accountant").click_button("Pull in") }

      it "lands the task in today", :aggregate_failures do
        expect(page).to have_current_path("/admin/tasks?filter=today")
        expect(page).to have_css(".task-title", text: "Email the accountant")
      end

      it "takes it off Next" do
        find(".subtab", text: "next").click

        expect(page).to have_no_css(".task-title", text: "Email the accountant")
      end
    end
  end

  describe "finishing a task" do
    before do
      find(".task", text: "Email the accountant").click_button(translate("ui.components.tasks.controls.start"))
      find(".task", text: "Email the accountant").click_button(translate("ui.components.tasks.controls.complete"))
    end

    it "files it out of the list it was in" do
      expect(page).to have_no_css(".task-title", text: "Email the accountant")
    end

    it "files it under the day it was finished" do
      find(".subtab", text: "completed").click

      expect(page).to have_css(".task-day-date").and have_css(".task-title", text: "Email the accountant")
    end

    it "offers to open it again from the archive" do
      find(".subtab", text: "completed").click

      expect(find(".task", text: "Email the accountant")).to have_button("Reopen")
    end
  end

  describe "canceling a task" do
    let(:mark) { translate("ui.components.tasks.closed.canceled") }

    before do
      find(".task", text: "Email the accountant").click_button(translate("ui.components.tasks.controls.cancel"))
      find(".toast", text: "Canceled")
      find(".subtab", text: "completed").click
    end

    it "files it under completed with its canceled mark" do
      expect(find(".task.canceled", text: "Email the accountant")).to have_css(".task-meta .pill", text: mark)
    end

    describe "reopening it" do
      before do
        find(".task", text: "Email the accountant").click_button(translate("ui.components.tasks.controls.reopen"))
        find(".toast", text: "Reopened")
        find(".subtab", text: "next").click
      end

      it "puts it back on its list as open", :aggregate_failures do
        expect(page).to have_css(".task-title", text: "Email the accountant")
        expect(find(".task", text: "Email the accountant")).to have_no_css(".task-meta .pill", text: mark)
        expect(repo.all_open.map(&:title)).to include("Email the accountant")
      end
    end
  end

  describe "editing a task" do
    before do
      create(:task_type, name: "Chore")
      visit "/admin/tasks?filter=next"
      open_editor("Email the accountant")
    end

    it "opens the form under the task" do
      expect(page).to have_field("task[title]", with: "Email the accountant")
    end

    it "saves what I change" do
      row = find(".task", text: "Email the accountant")
      row.fill_in("task[tags]", with: "admin")
      row.click_button("Save")

      expect(page).to have_css(".task-meta .task-tag", text: "#admin")
    end

    it "moves the task through the list field" do
      row = find(".task", text: "Email the accountant")
      row.select("someday", from: "task[list]")
      row.click_button("Save")
      find(".subtab", text: "someday").click

      expect(page).to have_css(".task-title", text: "Email the accountant")
    end

    it "closes without saving what I typed", :aggregate_failures do
      row = find(".task", text: "Email the accountant")
      row.fill_in("task[title]", with: "Something else")
      row.find(".task-editor-foot label", text: translate("ui.components.tasks.editor.cancel")).click

      expect(page).to have_css(".task-title", text: "Email the accountant")
      expect(page).to have_no_field("task[title]", with: "Something else")
    end
  end

  describe "linking tasks" do
    let(:task) { repo.all_open.find { it.title == "Email the accountant" } }
    let(:other) { repo.all_open.find { it.title == "Learn Elixir" } }

    def blocker = create(:task_link, from_task_id: other.id, to_task_id: task.id)

    def editor(name, **) = translate(["ui.components.tasks.link_editor", name].join("."), **)

    def find_task(query)
      open_editor("Email the accountant")
      row("Email the accountant").fill_in(editor(:label), with: query)
      row("Email the accountant").click_button(editor(:find))
    end

    def key(task) = "##{task.id}"

    def pick(title) = find(".task-link-target", text: title).click

    def row(title) = find(".task-title", exact_text: title).ancestor(".task")

    def stored = Tasks::Slice["relations.task_links"].to_a.map { it.to_h.values_at(:from_task_id, :to_task_id, :type) }

    describe "adding one" do
      before do
        find_task("elixir")
        find("#task-#{task.id}-link-kind").select(translate("ui.components.tasks.link_editor.kinds.blocked_by"))
        pick("Learn Elixir")
      end

      it "says so" do
        expect(page).to have_css(".toast", text: translate("tasks_page.toasts.linked"))
      end

      it "shows the chip on the row" do
        expect(row("Email the accountant"))
          .to have_css(".task-link", text: translate("ui.components.tasks.links.labels.blocked_by"))
      end

      it "shows the blocked pill while the blocker is open" do
        expect(row("Email the accountant"))
          .to have_css(".task-meta .pill", text: translate("ui.components.tasks.row.blocked"))
      end

      it "saves one blocks link from the other task", :aggregate_failures do
        expect(page).to have_css(".toast")
        expect(stored).to eq([[other.id, task.id, "blocks"]])
      end
    end

    it "finds the task by its key" do
      find_task("##{other.id}")

      expect(page).to have_css(".task-link-target", text: "Learn Elixir")
    end

    it "leaves the task itself out of the matches" do
      find_task(task.id.to_s)

      expect(page).to have_css(".task-link-editor", text: editor(:no_match))
    end

    describe "a task with a link" do
      before do
        blocker
        visit "/admin/tasks?filter=next"
      end

      it "removes it from the editor", :aggregate_failures do
        open_editor("Email the accountant")
        row("Email the accountant").click_button(editor(:remove, key: key(other)))

        expect(page).to have_css(".toast", text: translate("tasks_page.toasts.unlinked"))
        expect(row("Email the accountant")).to have_no_css(".task-link")
      end

      it "still moves while blocked" do
        row("Email the accountant").click_button(move_to("someday"))

        expect(page).to have_css(".toast", text: "Moved")
      end

      it "still completes while blocked" do
        row("Email the accountant").click_button(translate("ui.components.tasks.controls.start"))
        row("Email the accountant").click_button(translate("ui.components.tasks.controls.complete"))

        expect(page).to have_css(".toast", text: "Done")
      end

      it "loses the blocked pill once the blocker is canceled" do
        visit "/admin/tasks?filter=someday"
        row("Learn Elixir").click_button(translate("ui.components.tasks.controls.cancel"))
        find(".toast", text: "Canceled")
        find(".subtab", text: "next").click

        expect(row("Email the accountant")).to have_no_css(".task-meta .pill.pink")
      end

      it "loses the blocked pill once the blocker is done" do
        visit "/admin/tasks?filter=someday"
        row("Learn Elixir").click_button(translate("ui.components.tasks.controls.start"))
        row("Learn Elixir").click_button(translate("ui.components.tasks.controls.complete"))
        find(".subtab", text: "next").click

        expect(row("Email the accountant")).to have_no_css(".task-meta .pill.pink")
      end
    end

    describe "a refused link" do
      before { find_task("elixir") }

      def error = find("#task-#{task.id}-link-other-id-error")

      it "says the pair is taken when it was linked since the page loaded" do
        create(:task_link, from_task_id: other.id, to_task_id: task.id, type: "relates")
        pick("Learn Elixir")

        expect(error).to have_text(translate("ui.components.tasks.field_error.other_id.taken"))
      end

      it "says a task cannot link to itself" do
        page.execute_script("document.querySelector('.task-link-target').value = arguments[0]", task.id.to_s)
        pick("Learn Elixir")

        expect(error).to have_text(translate("ui.components.tasks.field_error.other_id.self"))
      end
    end
  end

  describe "deleting a task" do
    let(:row) { find(".task", text: "Email the accountant") }

    before { open_editor("Email the accountant") }

    it "asks with the confirmation text" do
      message = dismiss_confirm { row.click_button("Delete") }

      expect(message).to eq(translate("ui.components.tasks.editor.confirm_delete", task: "Email the accountant"))
    end

    it "keeps the task listed when I don't confirm", :aggregate_failures do
      dismiss_confirm { row.click_button("Delete") }

      expect(page).to have_no_css(".toast")
      expect(page).to have_css(".task-title", text: "Email the accountant")
    end

    it "deletes once I confirm" do
      accept_confirm { row.click_button("Delete") }

      expect(page).to have_css(".toast", text: "Task deleted")
    end
  end
end

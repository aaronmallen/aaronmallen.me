# frozen_string_literal: true

RSpec.describe "Admin tasks", type: :feature do
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:sprint_repo) { Tasks::Slice["repos.sprint_repo"] }

  def active = evaluate_script("document.activeElement.textContent.trim()")

  def cancel_task(scope)
    scope.click_button(translate("ui.components.tasks.controls.cancel"))
    confirm_dialog.click_button(translate("ui.components.confirm_dialog.accept"))
  end

  def confirm_dialog = find("dialog#confirm-dialog[open]")

  def create_task(title, list: "next", **fields)
    click_link("Create Task")
    within("dialog#task-create") do
      fill_in("task[title]", with: title)
      select(list, from: "task[list]")
      fields.each { |name, value| fill_in("task[#{name}]", with: value) }
      click_button("Create task")
    end
  end

  def modal = find("dialog#task-create[open]")

  def modal_x = "button[aria-label='#{translate('ui.components.tasks.create_dialog.close')}']"

  def move_to(list)
    named = translate(["ui.components.tasks.controls.lists", list].join("."))

    translate("ui.components.tasks.controls.move", list: named)
  end

  def open_editor(title)
    open_task(title)
    panel.click_link(translate("ui.views.tasks.show.edit"))
    modal.assert_selector("[data-task-edit]")
  end

  def open_task(title)
    find(".task", text: title).find(".task-title").click
    panel.assert_selector("h1", exact_text: title)
    settle("#task-panel")
  end

  def panel = find("dialog#task-panel[open]")

  def scripts_off
    page.driver.browser.page.disable_javascript
    visit "/admin/tasks?filter=next"
  end

  def scripts_on = page.driver.browser.page.command("Emulation.setScriptExecutionDisabled", value: false)

  def scroll_down
    execute_script(<<~JS)
      document.querySelector("[data-pools] .seg").scrollIntoView({ block: "center" });
      window.poolsLoaded = true;
      window.poolsScroll = window.scrollY;
    JS
  end

  def tag_task(title, tags)
    open_editor(title)
    fill_in("task[tags]", with: tags)
    click_button("Save")
  end

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
      expect(page.all(".subtab-count").map(&:text)).to eq(%w[0 0 1 1 0 0])
    end
  end

  describe "the Create Task button" do
    before { click_link("Create Task") }

    it "opens the dialog on the page you are on", :aggregate_failures do
      expect(page).to have_css("dialog#task-create[open]")
      expect(page).to have_current_path("/admin/tasks?filter=next")
    end

    it "puts the cursor in the title" do
      expect(evaluate_script("document.activeElement.name")).to eq("task[title]")
    end

    it "shuts on Cancel" do
      within("dialog#task-create") { click_button("Cancel") }

      expect(page).to have_no_css("dialog#task-create[open]")
    end

    it "stays open with what I typed on a click outside", :aggregate_failures do
      fill_in("task[title]", with: "Half a thought")
      page.driver.browser.mouse.click(x: 10, y: 700)

      expect(modal).to have_field("task[title]", with: "Half a thought")
    end

    it "shuts on the X" do
      modal.find(modal_x).click

      expect(page).to have_no_css("dialog#task-create[open]")
    end

    it "shuts on Escape" do
      modal.send_keys(:escape)

      expect(page).to have_no_css("dialog#task-create[open]")
    end

    it "fits a phone without scrolling the page sideways", :aggregate_failures do
      page.driver.resize(375, 800)

      expect(page).to have_css("dialog#task-create[open]")
      expect(evaluate_script("(d => d.scrollWidth > d.clientWidth)(document.documentElement)")).to be(false)
    end
  end

  describe "creating a task from the dialog" do
    let(:created) { repo.in_list("someday").find { it.title == "Call the #plumber" } }

    before { create_task("Call the #plumber", list: "someday", note: "the sink leaks", tags: "home, chores") }

    it "files it in the list it names" do
      expect(page).to have_css(".task-title", text: "Call the #plumber")
    end

    it "says so" do
      expect(page).to have_css("[data-toast]", text: "Task captured")
    end

    it "keeps the note, the #word in the title and the tags", :aggregate_failures do
      page.assert_selector(".task-title", text: "Call the #plumber")

      expect(created.note).to eq("the sink leaks")
      expect(created.tags.map(&:name)).to contain_exactly("home", "chores")
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

  describe "clicking a tag" do
    before do
      create(:task, title: "Fix the feed", tags: %w[site])
      create(:task, title: "Email the plumber", tags: %w[home])
      visit "/admin/tasks?filter=next"
      find(".task", text: "Fix the feed").click_link("#site")
    end

    it "opens the list showing only tasks with that tag", :aggregate_failures do
      expect(page).to have_current_path("/admin/tasks?filter=next&q=tag:site")
      expect(all(".task-title").map(&:text)).to eq(["Fix the feed"])
    end
  end

  def watch_clipboard
    page.execute_script(<<~JS)
      window.copiedKeys = [];
      Object.defineProperty(navigator, "clipboard", {
        value: { writeText: (text) => { window.copiedKeys.push(text); return Promise.resolve(); } },
      });
    JS
  end

  describe "the key" do
    let(:task) { repo.in_list("next").find { it.title == "Email the accountant" } }
    let(:key) { "##{task.id}" }

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
      before { scripts_off }

      after { scripts_on }

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

    it "takes a new task into the sprint", :aggregate_failures do
      create_task("Ship the screen", list: "today")

      expect(page).to have_css(".task-title", text: "Ship the screen")
      expect(repo.in_sprint(sprint_repo.on(Blog::TimeZone.today).id).map(&:title)).to eq(["Ship the screen"])
    end

    it "drops the planner once the sprint holds a task" do
      create_task("Ship the screen", list: "today")

      expect(page).to have_css(".task-title", text: "Ship the screen").and have_no_css(".task-planner")
    end

    describe "switching the pool to someday" do
      before do
        page.driver.resize(1024, 400)
        scroll_down
        find(".task-planner .seg-option", exact_text: "someday · 1").click
      end

      it "stays on the tasks screen" do
        expect(page).to have_current_path("/admin/tasks?filter=today&pool=someday")
      end

      it "offers what is in someday", :aggregate_failures do
        expect(page).to have_css(".task-planner .li-title", text: "Learn Elixir")
        expect(page).to have_no_css(".task-planner .li-title", text: "Email the accountant")
      end

      it "marks someday as the pool on show" do
        expect(page).to have_css(".task-planner .seg-option.current[aria-current='true']", exact_text: "someday · 1")
      end

      it "switches without loading the page", :aggregate_failures do
        expect(page).to have_css(".task-planner .li-title", text: "Learn Elixir")
        expect(evaluate_script("window.poolsLoaded")).to be(true)
        expect(evaluate_script("window.scrollY > 0 && window.scrollY === window.poolsScroll")).to be(true)
      end

      it "opens someday again on reload" do
        refresh

        expect(page).to have_css(".task-planner .li-title", text: "Learn Elixir")
      end

      it "returns to someday after pulling from it" do
        find(".task-planner .li", text: "Learn Elixir").click_button("Pull in")

        expect(page).to have_current_path("/admin/tasks?filter=today&pool=someday")
      end
    end

    describe "switching the pool with scripts off" do
      before do
        page.driver.browser.page.disable_javascript
        visit "/admin/tasks?filter=today"
        find(".task-planner .seg-option", exact_text: "someday · 1").click
      end

      after { scripts_on }

      it "loads someday from the link", :aggregate_failures do
        expect(page).to have_current_path("/admin/tasks?filter=today&pool=someday")
        expect(page).to have_css(".task-planner .li-title", text: "Learn Elixir")
        expect(page).to have_no_css(".task-planner .li-title", text: "Email the accountant")
      end
    end

    describe "pulling from next" do
      before { find(".task-planner .li", text: "Email the accountant").click_button("Pull in") }

      it "lands the task in today", :aggregate_failures do
        expect(page).to have_current_path("/admin/tasks?filter=today&pool=next")
        expect(page).to have_css(".task-title", text: "Email the accountant")
      end

      it "takes it off Next" do
        find(".subtab", text: "next").click

        expect(page).to have_no_css(".task-title", text: "Email the accountant")
      end
    end
  end

  describe "an imported task" do
    let(:issue_url) { "https://github.com/aaronmallen/aaronmallen.me/issues/42" }

    before do
      create(:task_source, task: create(:task, :external, title: "Fix the feed"), url: issue_url)
      find(".subtab", text: "external").click
    end

    it "shows on the external tab with a link to its issue", :aggregate_failures do
      expect(page).to have_current_path("/admin/tasks?filter=external")
      expect(find(".task", text: "Fix the feed")).to have_link("aaronmallen/aaronmallen.me#42", href: issue_url)
    end

    it "takes a tag from the editor and stays on external", :aggregate_failures do
      tag_task("Fix the feed", "site")

      expect(page).to have_current_path("/admin/tasks?filter=external")
      expect(find(".task", text: "Fix the feed")).to have_css(".tag", text: "#site")
    end

    describe "pulled in from the planner" do
      before do
        visit "/admin/tasks?filter=today"
        find(".task-planner .seg-option", exact_text: "external · 1").click
        find(".task-planner .li", text: "Fix the feed").click_button("Pull in")
      end

      it "lands in today, still linked to its issue", :aggregate_failures do
        expect(page).to have_current_path("/admin/tasks?filter=today&pool=external")
        expect(find(".task", text: "Fix the feed")).to have_link(href: issue_url)
      end

      it "leaves external" do
        find(".subtab", text: "external").click

        expect(page).to have_no_css(".task-title", text: "Fix the feed")
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
      cancel_task(find(".task", text: "Email the accountant"))
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

  describe "confirming a cancel" do
    let(:cancel) { translate("ui.components.tasks.controls.cancel") }
    let(:message) { translate("ui.components.tasks.controls.confirm_cancel", task: "Email the accountant") }
    let(:task) { repo.in_list("next").find { it.title == "Email the accountant" } }

    def focused_label = evaluate_script("document.activeElement.getAttribute('aria-label')")

    def row(title) = find(".task-title", exact_text: title).ancestor(".task")

    def still_open? = repo.all_open.map(&:title).include?("Email the accountant")

    describe "from a row" do
      before { row("Email the accountant").click_button(cancel) }

      it "asks in the styled dialog" do
        expect(confirm_dialog).to have_css("#confirm-dialog-message", exact_text: message)
      end

      it "keeps the task open when I say no", :aggregate_failures do
        confirm_dialog.click_button(translate("ui.components.confirm_dialog.decline"))

        expect(page).to have_no_css("dialog#confirm-dialog[open]")
        expect(page).to have_no_css(".toast")
        expect(still_open?).to be(true)
      end

      it "hands focus back to the cancel button when I say no", :aggregate_failures do
        confirm_dialog.click_button(translate("ui.components.confirm_dialog.decline"))

        expect(page).to have_no_css("dialog#confirm-dialog[open]")
        expect(focused_label).to eq(cancel)
      end

      it "keeps the task open on Escape and hands focus back", :aggregate_failures do
        confirm_dialog.send_keys(:escape)

        expect(page).to have_no_css("dialog#confirm-dialog[open]")
        expect(focused_label).to eq(cancel)
        expect(still_open?).to be(true)
      end

      it "cancels the task when I say yes", :aggregate_failures do
        confirm_dialog.click_button(translate("ui.components.confirm_dialog.accept"))

        expect(page).to have_css(".toast", text: "Canceled")
        expect(still_open?).to be(false)
      end
    end

    describe "from the task page" do
      before do
        visit "/admin/tasks/#{task.id}?filter=next&origin=tasks"
        find(".task-read-acts").click_button(cancel)
      end

      it "asks in the styled dialog" do
        expect(confirm_dialog).to have_css("#confirm-dialog-message", exact_text: message)
      end

      it "cancels the task when I say yes", :aggregate_failures do
        confirm_dialog.click_button(translate("ui.components.confirm_dialog.accept"))

        expect(page).to have_css(".toast", text: "Canceled")
        expect(still_open?).to be(false)
      end
    end

    describe "from the panel" do
      before do
        open_task("Email the accountant")
        panel.click_button(cancel)
      end

      it "asks in the styled dialog over the panel" do
        expect(confirm_dialog).to have_css("#confirm-dialog-message", exact_text: message)
      end

      it "keeps the panel and the task open on Escape, with focus on the cancel button", :aggregate_failures do
        confirm_dialog.send_keys(:escape)

        expect(page).to have_no_css("dialog#confirm-dialog[open]").and have_css("dialog#task-panel[open]")
        expect(focused_label).to eq(cancel)
        expect(still_open?).to be(true)
      end
    end

    describe "on a page without the styled dialog" do
      before { execute_script("document.getElementById('confirm-dialog').remove()") }

      it "asks with the browser's confirm" do
        asked = dismiss_confirm { row("Email the accountant").click_button(cancel) }

        expect(asked).to eq(message)
      end
    end

    describe "with scripts off" do
      before { scripts_off }

      after { scripts_on }

      it "still cancels the task with a plain post", :aggregate_failures do
        find(".task", text: "Email the accountant").click_button(cancel)

        expect(page).to have_no_css(".task-title", text: "Email the accountant")
        expect(still_open?).to be(false)
      end
    end
  end

  describe "moving an in-progress task out of today" do
    let(:message) { translate("ui.components.tasks.controls.confirm_move", task: "Ship the screen", list: "Next") }
    let(:sprint) { sprint_repo.on(Blog::TimeZone.today) || create(:sprint, sprint_date: Blog::TimeZone.today) }
    let(:task) { repo.all_open.find { it.title == "Ship the screen" } }

    def row(title) = find(".task-title", exact_text: title).ancestor(".task")

    before { create(:task, :in_progress, :in_sprint, sprint_id: sprint.id, title: "Ship the screen") }

    describe "from a row on the tasks page" do
      before do
        visit "/admin/tasks?filter=today"
        row("Ship the screen").click_button(move_to("next"))
      end

      it "asks in the styled dialog" do
        expect(confirm_dialog).to have_css("#confirm-dialog-message", exact_text: message)
      end

      it "keeps the task in today and in progress when I say no", :aggregate_failures do
        confirm_dialog.click_button(translate("ui.components.confirm_dialog.decline"))

        expect(page).to have_no_css("dialog#confirm-dialog[open]")
        expect(task).to have_attributes(list: nil, sprint_id: sprint.id, status: "in_progress")
      end

      it "moves it to next as open when I say yes", :aggregate_failures do
        confirm_dialog.click_button(translate("ui.components.confirm_dialog.accept"))

        expect(page).to have_current_path("/admin/tasks?filter=next")
        expect(task).to have_attributes(list: "next", sprint_id: nil, status: "open")
      end
    end

    describe "from a row on Today" do
      before do
        visit "/admin"
        row("Ship the screen").click_button(move_to("next"))
      end

      it "asks in the styled dialog" do
        expect(confirm_dialog).to have_css("#confirm-dialog-message", exact_text: message)
      end

      it "moves it to next as open when I say yes", :aggregate_failures do
        confirm_dialog.click_button(translate("ui.components.confirm_dialog.accept"))

        expect(page).to have_no_css(".task-title", exact_text: "Ship the screen")
        expect(task).to have_attributes(list: "next", status: "open")
      end
    end

    describe "an open task" do
      before do
        create(:task, :in_sprint, sprint_id: sprint.id, title: "Water the plants")
        visit "/admin/tasks?filter=today"
        row("Water the plants").click_button(move_to("next"))
      end

      it "moves without asking", :aggregate_failures do
        expect(page).to have_current_path("/admin/tasks?filter=next")
        expect(page).to have_no_css("dialog#confirm-dialog[open]")
      end
    end
  end

  describe "dropping a sprint" do
    before do
      create(:sprint, sprint_date: Blog::TimeZone.today + 2)
      visit "/admin/tasks?filter=upcoming"
    end

    it "still asks with the browser's confirm" do
      asked = dismiss_confirm { click_button(translate("ui.components.tasks.upcoming_sprints.drop")) }

      expect(asked).to start_with("Drop the sprint for")
    end
  end

  describe "opening a task" do
    let(:task) { repo.in_list("next").find { it.title == "Email the accountant" } }
    let(:key) { "##{task.id}" }

    def sideways?(selector) = evaluate_script("(d => d.scrollWidth > d.clientWidth)(#{selector})")

    before { open_task("Email the accountant") }

    it "shows it in the panel and stays on the list", :aggregate_failures do
      expect(page).to have_current_path("/admin/tasks?filter=next")
      expect(panel).to have_css(".task-key", exact_text: key)
    end

    it "closes on Escape and hands focus back to the row", :aggregate_failures do
      panel.send_keys(:escape)

      expect(page).to have_no_css("dialog#task-panel[open]")
      expect(active).to eq("Email the accountant")
    end

    it "closes on a click outside and hands focus back to the row", :aggregate_failures do
      page.driver.browser.mouse.click(x: 1200, y: 400)

      expect(page).to have_no_css("dialog#task-panel[open]")
      expect(active).to eq("Email the accountant")
    end

    it "closes on the back button" do
      panel.click_link(translate("ui.views.tasks.show.back_tasks"))

      expect(page).to have_no_css("dialog#task-panel[open]").and have_current_path("/admin/tasks?filter=next")
    end

    it "copies the key from the panel" do
      watch_clipboard
      panel.find(".task-key").click

      expect(page).to have_css(".toast", text: translate("ui.components.tasks.task_key.copied", key:))
    end

    it "comes back to the list after an action in the panel", :aggregate_failures do
      cancel_task(panel)

      expect(page).to have_css(".toast", text: "Canceled").and have_no_css("dialog#task-panel[open]")
      expect(page).to have_current_path("/admin/tasks?filter=next")
    end

    it "spans a phone with no sideways scroll", :aggregate_failures do
      page.driver.resize(375, 800)

      expect(evaluate_script("document.querySelector('#task-panel').getBoundingClientRect().width")).to eq(375)
      expect(sideways?("document.querySelector('#task-panel')")).to be(false)
      expect(sideways?("document.documentElement")).to be(false)
    end
  end

  describe "commenting from the panel" do
    let(:task) { repo.in_list("next").find { it.title == "Email the accountant" } }
    let(:comments) { Tasks::Slice["relations.task_comments"] }

    def bodies = comments.to_a.map { it[:body] }

    def comment_on(scope) = scope.find(".task-comment", text: "Sent the forms")

    describe "with none yet" do
      before { open_task("Email the accountant") }

      it "heads the section Activity" do
        expect(panel).to have_css(".task-activity .card-title",
                                  exact_text: translate("ui.components.tasks.timeline.title"))
      end

      it "adds a comment and comes back to the list", :aggregate_failures do
        panel.fill_in(translate("ui.components.tasks.timeline.add_label"), with: "Sent the **forms**")
        panel.click_button(translate("ui.components.tasks.timeline.add"))

        expect(page).to have_css(".toast", text: translate("tasks_page.toasts.comment_added"))
        expect(page).to have_current_path("/admin/tasks?filter=next")
        expect(bodies).to eq(["Sent the **forms**"])
      end
    end

    describe "with a comment" do
      before do
        create(:task_comment, task_id: task.id, body: "Sent the forms")
        open_task("Email the accountant")
      end

      it "edits it", :aggregate_failures do
        comment_on(panel).find("summary", text: translate("ui.components.tasks.timeline.edit")).click
        comment_on(panel).fill_in(translate("ui.components.tasks.timeline.edit_label"), with: "Sent the forms twice")
        comment_on(panel).click_button(translate("ui.components.tasks.timeline.save"))

        expect(page).to have_css(".toast", text: translate("tasks_page.toasts.comment_saved"))
        expect(bodies).to eq(["Sent the forms twice"])
      end

      it "deletes it once asked", :aggregate_failures do
        comment_on(panel).click_button(translate("ui.components.tasks.timeline.delete"))
        confirm_dialog.click_button(translate("ui.components.confirm_dialog.accept"))

        expect(page).to have_css(".toast", text: translate("tasks_page.toasts.comment_deleted"))
        expect(bodies).to be_empty
      end
    end
  end

  describe "commenting with scripts off" do
    let(:task) { repo.in_list("next").find { it.title == "Email the accountant" } }
    let(:comments) { Tasks::Slice["relations.task_comments"] }

    def bodies = comments.to_a.map { it[:body] }

    def comment_on = find(".task-comment", text: "Sent the forms")

    before do
      create(:task_comment, task_id: task.id, body: "Sent the forms")
      scripts_off
      find(".task", text: "Email the accountant").find(".task-title").click
    end

    after { scripts_on }

    it "adds a comment", :aggregate_failures do
      fill_in(translate("ui.components.tasks.timeline.add_label"), with: "Called them")
      click_button(translate("ui.components.tasks.timeline.add"))

      expect(page).to have_current_path("/admin/tasks?filter=next")
      expect(bodies).to eq(["Sent the forms", "Called them"])
    end

    it "edits a comment", :aggregate_failures do
      comment_on.find("summary").click
      comment_on.fill_in(translate("ui.components.tasks.timeline.edit_label"), with: "Sent the forms twice")
      comment_on.click_button(translate("ui.components.tasks.timeline.save"))

      expect(page).to have_current_path("/admin/tasks?filter=next")
      expect(bodies).to eq(["Sent the forms twice"])
    end

    it "deletes a comment", :aggregate_failures do
      comment_on.click_button(translate("ui.components.tasks.timeline.delete"))

      expect(page).to have_current_path("/admin/tasks?filter=next")
      expect(bodies).to be_empty
    end
  end

  describe "writing Markdown in a task" do
    let(:task) { repo.in_list("next").find { it.title == "Email the accountant" } }
    let(:unsafe) { "<script>window.ran = true</script>\n\n<details><summary>M</summary>x</details>" }

    def add_label = translate("ui.components.tasks.timeline.add_label")

    def bold(editor) = editor.find("[role='toolbar'] button[aria-label='Bold']").click

    def editor(scope, label) = scope.find_field(label).ancestor("[data-markdown-editor]")

    def write_and_preview(editor, label, text)
      editor.fill_in(label, with: text)
      editor.find(".seg-option", text: translate("ui.components.markdown_editor.preview")).click
    end

    shared_examples "a comment editor" do
      it "inserts a snippet from the toolbar" do
        bold(editor(scope, add_label))

        expect(scope.find_field(add_label).value).to eq("**bold**")
      end

      it "previews the comment through the task renderer", :aggregate_failures do
        box = editor(scope, add_label)
        write_and_preview(box, add_label, unsafe)

        expect(box).to have_css(".preview details summary", text: "M")
        expect(box).to have_no_css(".preview script", visible: :all)
        expect(evaluate_script("window.ran")).to be_nil
      end
    end

    describe "in the panel" do
      before { open_task("Email the accountant") }

      it_behaves_like "a comment editor" do
        let(:scope) { panel }
      end
    end

    describe "on the task page" do
      before { visit "/admin/tasks/#{task.id}" }

      it_behaves_like "a comment editor" do
        let(:scope) { page }
      end
    end

    describe "the note in the editor dialog" do
      def note_label = translate("ui.components.tasks.task_form.note")

      before { open_editor("Email the accountant") }

      it "inserts a snippet from the toolbar" do
        bold(editor(modal, note_label))

        expect(modal.find_field(note_label).value).to eq("**bold**")
      end

      it "previews the note through the task renderer", :aggregate_failures do
        box = editor(modal, note_label)
        write_and_preview(box, note_label, "<script>window.ran = true</script>\n\nsay **why**")

        expect(box).to have_css(".preview strong", exact_text: "why")
        expect(box).to have_no_css(".preview script", visible: :all)
      end

      it "saves the note it formats" do
        bold(editor(modal, note_label))
        modal.click_button("Save")

        page.assert_no_selector("dialog#task-create[open]")

        expect(repo.by_id(task.id).note).to eq("**bold**")
      end
    end
  end

  describe "opening a task with scripts off" do
    let(:task) { repo.in_list("next").find { it.title == "Email the accountant" } }

    before do
      scripts_off
      find(".task", text: "Email the accountant").find(".task-title").click
    end

    after { scripts_on }

    it "opens its page", :aggregate_failures do
      expect(page).to have_current_path("/admin/tasks/#{task.id}?filter=next&origin=tasks")
      expect(page).to have_css("h1", exact_text: "Email the accountant")
    end
  end

  describe "opening a task from Today" do
    before do
      sprint = sprint_repo.on(Blog::TimeZone.today) || create(:sprint, sprint_date: Blog::TimeZone.today)
      create(:task, :in_sprint, sprint_id: sprint.id, title: "Ship it")
      visit "/admin"
      open_task("Ship it")
    end

    it "shows it in the panel and stays on Today" do
      expect(page).to have_current_path("/admin")
    end

    it "comes back to Today after an action in the panel", :aggregate_failures do
      panel.click_button(translate("ui.components.tasks.controls.start"))

      expect(page).to have_css(".toast", text: "Started")
      expect(page).to have_current_path("/admin")
    end
  end

  describe "creating a task from Today" do
    let(:today) { Blog::TimeZone.today }

    before do
      visit "/admin"
      click_link("Create Task")
    end

    it "opens the dialog on Today", :aggregate_failures do
      expect(modal).to have_select("task[list]", selected: "today")
      expect(page).to have_current_path("/admin")
    end

    describe "saving it" do
      before do
        within(modal) do
          fill_in("task[title]", with: "Ship the screen")
          click_button("Create task")
        end
      end

      it "comes back to Today with the task in the sprint", :aggregate_failures do
        expect(page).to have_css(".sprint-panel .task-title", text: "Ship the screen")
        expect(page).to have_current_path("/admin")
      end

      it "puts the task in today's sprint" do
        page.assert_selector(".sprint-panel .task-title", text: "Ship the screen")

        expect(repo.in_sprint(sprint_repo.on(today).id).map(&:title)).to eq(["Ship the screen"])
      end
    end

    it "fits a phone without scrolling the page sideways", :aggregate_failures do
      page.driver.resize(375, 800)

      expect(modal).to have_field("task[title]")
      expect(evaluate_script("(d => d.scrollWidth > d.clientWidth)(document.documentElement)")).to be(false)
    end
  end

  describe "creating a task from Today with scripts off" do
    before do
      page.driver.browser.page.disable_javascript
      visit "/admin"
      click_link("Create Task")
    end

    after { scripts_on }

    it "leads to the new task page", :aggregate_failures do
      expect(page).to have_current_path("/admin/tasks/new?origin=today")
      expect(page).to have_select("task[list]", selected: "today")
    end

    it "comes back to Today after the save", :aggregate_failures do
      fill_in("task[title]", with: "Ship the screen")
      click_button("Create task")

      expect(page).to have_current_path("/admin")
      expect(page).to have_css(".sprint-panel .task-title", text: "Ship the screen")
    end
  end

  describe "pulling a task into Today's sprint while it holds tasks" do
    before do
      sprint = sprint_repo.on(Blog::TimeZone.today) || create(:sprint, sprint_date: Blog::TimeZone.today)
      create(:task, :in_sprint, sprint_id: sprint.id, title: "Ship it")
      visit "/admin"
      find(".sprint-panel .task-planner-pull .li", text: "Email the accountant").click_button("Pull in")
    end

    it "adds it to the sprint and stays on Today", :aggregate_failures do
      expect(page).to have_current_path("/admin?pool=next")
      expect(page).to have_css(".sprint-panel .task-title", text: "Email the accountant")
      expect(page).to have_css(".sprint-panel .task-title", text: "Ship it")
    end
  end

  describe "opening a task from the archive" do
    before do
      create(:task, :done, title: "Filed the taxes")
      visit "/admin/tasks?filter=completed"
      open_task("Filed the taxes")
    end

    it "shows it in the panel and stays on the archive" do
      expect(page).to have_current_path("/admin/tasks?filter=completed")
    end

    it "comes back to the archive after an action in the panel", :aggregate_failures do
      panel.click_button(translate("ui.components.tasks.controls.reopen"))

      expect(page).to have_css(".toast", text: "Reopened")
      expect(page).to have_current_path("/admin/tasks?filter=completed")
    end
  end

  describe "reading a note with links" do
    def link_box = evaluate_script(<<~JS)
      (() => {
        const link = document.querySelector('#task-panel .task-body a');
        const box = link.getBoundingClientRect();
        return { display: getComputedStyle(link).display, height: box.height, width: box.width };
      })()
    JS

    before do
      create(:task, title: "Read the guide", note: "start with [the guide](https://example.com) today")
      visit "/admin/tasks?filter=next"
      open_task("Read the guide")
    end

    it "keeps a link inline with its sentence on a wide screen", :aggregate_failures do
      expect(link_box["display"]).to eq("inline")
      expect(link_box["height"]).to be < 44
    end

    it "gives a link a tap square on a phone", :aggregate_failures do
      page.driver.resize(375, 800)

      expect(link_box["height"]).to be >= 44
      expect(link_box["width"]).to be >= 44
    end
  end

  describe "editing a task" do
    before { open_editor("Email the accountant") }

    it "closes the panel and opens the modal filled with the task", :aggregate_failures do
      expect(page).to have_no_css("dialog#task-panel[open]")
      expect(modal).to have_field("task[title]", with: "Email the accountant")
      expect(modal).to have_css(".card-title", exact_text: translate("ui.components.tasks.create_dialog.edit_title"))
    end

    it "saves what I change and comes back to the list", :aggregate_failures do
      fill_in("task[tags]", with: "admin")
      click_button("Save")

      expect(page).to have_css(".toast", text: "Task saved")
      expect(page).to have_current_path("/admin/tasks?filter=next")
      expect(find(".task", text: "Email the accountant")).to have_css(".task-meta .tag", text: "#admin")
    end

    it "moves the task through the list field" do
      select("someday", from: "task[list]")
      click_button("Save")
      find(".subtab", text: "someday").click

      expect(page).to have_css(".task-title", text: "Email the accountant")
    end

    def fail_save = save_with(title: " ", tags: "not_a_tag")

    def save_with(**fields)
      fields.each { |name, value| fill_in("task[#{name}]", with: value) }
      click_button("Save")
    end

    it "keeps what I typed and says what went wrong in the modal when the save fails", :aggregate_failures do
      fail_save

      expect(modal).to have_css(".field-error", text: translate("ui.components.tasks.field_error.title.blank"))
      expect(modal).to have_field("task[tags]", with: "not_a_tag")
      expect(page).to have_current_path("/admin/tasks?filter=next")
    end

    it "saves once the errors are fixed" do
      fail_save
      modal.assert_selector(".field-error", count: 2)
      save_with(title: "Email the bookkeeper", tags: "")

      expect(page).to have_css(".task-title", text: "Email the bookkeeper")
    end

    it "closes on Cancel without saving and hands focus back to the row", :aggregate_failures do
      fill_in("task[title]", with: "Something else")
      modal.click_link(translate("ui.views.tasks.edit.cancel"))

      expect(page).to have_no_css("dialog#task-create[open]")
      expect(active).to eq("Email the accountant")
      expect(repo.in_list("next").map(&:title)).to include("Email the accountant")
    end

    it "keeps the X after the swap to the edit form" do
      expect(modal).to have_css(modal_x)
    end

    it "keeps the X after a failed save swaps the form again" do
      fail_save

      expect(modal).to have_css(modal_x)
    end

    it "closes on the X without saving and hands focus back to the row", :aggregate_failures do
      fill_in("task[title]", with: "Something else")
      modal.find(modal_x).click

      expect(page).to have_no_css("dialog#task-create[open]")
      expect(active).to eq("Email the accountant")
      expect(repo.in_list("next").map(&:title)).to include("Email the accountant")
    end

    it "gives the Create Task dialog back its X once closed" do
      modal.send_keys(:escape)
      click_link("Create Task")

      expect(modal).to have_css(modal_x)
    end

    it "gives the Create Task dialog back its own form once closed", :aggregate_failures do
      modal.send_keys(:escape)
      click_link("Create Task")

      expect(modal).to have_css(".card-title", exact_text: translate("ui.components.tasks.create_dialog.title"))
      expect(modal).to have_field("task[title]", with: "")
    end

    it "fits a phone without scrolling the page sideways" do
      page.driver.resize(375, 800)

      expect(evaluate_script("(d => d.scrollWidth > d.clientWidth)(document.documentElement)")).to be(false)
    end
  end

  describe "editing a task with scripts off" do
    before do
      scripts_off
      find(".task", text: "Email the accountant").find(".task-title").click
      click_link(translate("ui.views.tasks.show.edit"))
    end

    after { scripts_on }

    it "opens the edit page" do
      expect(page).to have_css("h1", exact_text: "Email the accountant").and have_field("task[title]")
    end

    it "shows what went wrong on the page when the save fails" do
      fill_in("task[title]", with: " ")
      click_button("Save")

      expect(page).to have_css(".field-error", text: translate("ui.components.tasks.field_error.title.blank"))
    end
  end

  describe "editing from a row's pen" do
    def pen = find(".task", text: "Email the accountant").find("a[data-task-open-edit]")

    def pen_label = evaluate_script("document.activeElement.getAttribute('aria-label')")

    before do
      pen.click
      modal.assert_selector("[data-task-edit]")
    end

    it "opens the modal filled with the task and never opens the panel", :aggregate_failures do
      expect(modal).to have_field("task[title]", with: "Email the accountant")
      expect(page).to have_no_css("dialog#task-panel[open]")
      expect(evaluate_script("document.querySelector('[data-task-panel-body]').childElementCount")).to eq(0)
    end

    it "saves what I change and reloads the list", :aggregate_failures do
      fill_in("task[tags]", with: "admin")
      click_button("Save")

      expect(page).to have_css(".toast", text: "Task saved")
      expect(page).to have_current_path("/admin/tasks?filter=next")
      expect(find(".task", text: "Email the accountant")).to have_css(".task-meta .tag", text: "#admin")
    end

    it "hands focus back to the pen when the modal closes on Cancel", :aggregate_failures do
      modal.click_link(translate("ui.views.tasks.edit.cancel"))

      expect(page).to have_no_css("dialog#task-create[open]")
      expect(pen_label).to eq(translate("ui.components.tasks.row.edit"))
    end

    it "hands focus back to the pen when the modal closes on Escape", :aggregate_failures do
      modal.send_keys(:escape)

      expect(page).to have_no_css("dialog#task-create[open]")
      expect(pen_label).to eq(translate("ui.components.tasks.row.edit"))
    end
  end

  describe "editing from a row's pen with scripts off" do
    before do
      scripts_off
      find(".task", text: "Email the accountant").find("a[data-task-open-edit]").click
    end

    after { scripts_on }

    it "opens the edit page" do
      expect(page).to have_css("h1", exact_text: "Email the accountant").and have_field("task[title]")
    end

    it "comes back to the row's list on save", :aggregate_failures do
      fill_in("task[tags]", with: "admin")
      click_button("Save")

      expect(page).to have_current_path("/admin/tasks?filter=next")
      expect(find(".task", text: "Email the accountant")).to have_css(".task-meta .tag", text: "#admin")
    end
  end

  describe "a row's buttons on a phone" do
    before { page.driver.resize(375, 800) }

    def pen_box = evaluate_script(<<~JS)
      (r => ({ right: r.right, width: r.width, height: r.height }))(
        document.querySelector(".task a[data-task-open-edit]").getBoundingClientRect()
      )
    JS

    it "fit without scrolling the page sideways", :aggregate_failures do
      expect(pen_box["right"]).to be <= 375
      expect(evaluate_script("(d => d.scrollWidth > d.clientWidth)(document.documentElement)")).to be(false)
    end

    it "give the pen a tap square", :aggregate_failures do
      expect(pen_box["width"]).to be >= 44
      expect(pen_box["height"]).to be >= 44
    end
  end

  describe "linking tasks" do
    let(:task) { repo.all_open.find { it.title == "Email the accountant" } }
    let(:other) { repo.all_open.find { it.title == "Learn Elixir" } }

    def blocker = create(:task_link, from_task_id: other.id, to_task_id: task.id)

    def editor(name, **) = translate(["ui.components.tasks.link_editor", name].join("."), **)

    def find_task(query)
      open_task("Email the accountant")
      fill_in(editor(:label), with: query)
      click_button(editor(:find))
    end

    def key(task) = "##{task.id}"

    def kind(name) = translate(["ui.components.tasks.link_editor.kinds", name].join("."))

    def kind_select = find("#task-#{task.id}-link-kind")

    def pick(title) = find(".task-link-target", text: title).click

    def pick_kind_and_find(query)
      kind_select.select(kind(:blocked_by))
      fill_in(editor(:label), with: query)
      click_button(editor(:find))
      find(".task-link-target", text: "Learn Elixir")
    end

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

    describe "a type picked before the find in the panel" do
      before do
        open_task("Email the accountant")
        pick_kind_and_find("elixir")
      end

      it "stays picked once the matches load", :aggregate_failures do
        expect(panel).to have_css(".task-link-target", text: "Learn Elixir")
        expect(kind_select.value).to eq("blocked_by")
        expect(page).to have_current_path("/admin/tasks?filter=next")
      end

      it "adds the link with that type" do
        pick("Learn Elixir")
        find(".toast", text: translate("tasks_page.toasts.linked"))

        expect(stored).to eq([[other.id, task.id, "blocks"]])
      end
    end

    describe "a type picked before the find with scripts off" do
      before do
        scripts_off
        find(".task", text: "Email the accountant").find(".task-title").click
        pick_kind_and_find("elixir")
      end

      after { scripts_on }

      it "stays picked once the page comes back" do
        expect(kind_select.value).to eq("blocked_by")
      end

      it "adds the link with that type" do
        pick("Learn Elixir")
        find(".toast", text: translate("tasks_page.toasts.linked"), visible: :all)

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

      it "shows the linked task in the panel when I click it", :aggregate_failures do
        open_task("Email the accountant")
        panel.click_link("Learn Elixir")

        expect(panel).to have_css("h1", exact_text: "Learn Elixir")
        expect(page).to have_current_path("/admin/tasks?filter=next")
      end

      it "removes it from the task's page", :aggregate_failures do
        open_task("Email the accountant")
        click_button(editor(:remove, key: key(other)))

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
        cancel_task(row("Learn Elixir"))
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

  describe "linking records" do
    let(:task) { repo.all_open.find { it.title == "Email the accountant" } }
    let!(:post_record) { create(:post, title: "Filing the quarterly taxes") }

    def find_record(query)
      within(".record-picker") do
        fill_in(picker(:label), with: query)
        click_button(picker(:find))
      end
      find(".record-picker-target", text: "Filing the quarterly taxes")
    end

    def linked = Links::Slice["queries.record_links"].call("task", task.id)

    def picker(name) = translate(["ui.components.record_links.picker", name].join("."))

    def remove_label = translate("ui.components.record_links.section.remove", title: "Filing the quarterly taxes")

    describe "in the panel" do
      before do
        open_task("Email the accountant")
        find_record("quarterly")
      end

      it "finds the record without leaving the panel", :aggregate_failures do
        expect(panel).to have_css(".record-picker-target", text: "Filing the quarterly taxes")
        expect(page).to have_current_path("/admin/tasks?filter=next")
      end

      it "links the record I pick", :aggregate_failures do
        find(".record-picker-target", text: "Filing the quarterly taxes").click

        expect(page).to have_css(".toast", text: translate("tasks_page.toasts.record_linked"))
        expect(linked.fetch("post").map(&:id)).to eq([post_record.id])
      end

      it "spans a phone with the matches and no sideways scroll", :aggregate_failures do
        page.driver.resize(375, 800)

        expect(evaluate_script("(d => d.scrollWidth > d.clientWidth)(document.querySelector('#task-panel'))"))
          .to be(false)
        expect(evaluate_script("(d => d.scrollWidth > d.clientWidth)(document.documentElement)")).to be(false)
      end
    end

    describe "a linked record in the panel" do
      before do
        Links::Slice["operations.link_records"]
          .call("task", task.id, { other_kind: "post", other_id: post_record.id })
        open_task("Email the accountant")
      end

      it "links to the record's page" do
        expect(panel.find(".record-links"))
          .to have_link("Filing the quarterly taxes", href: "/admin/posts/#{post_record.id}/edit")
      end

      it "removes it", :aggregate_failures do
        click_button(remove_label)

        expect(page).to have_css(".toast", text: translate("tasks_page.toasts.record_unlinked"))
        expect(linked).to be_empty
      end
    end

    describe "with scripts off" do
      def open_page = find(".task", text: "Email the accountant").find(".task-title").click

      def pick
        find(".record-picker-target", text: "Filing the quarterly taxes").click
        find(".toast", text: translate("tasks_page.toasts.record_linked"), visible: :all)
      end

      before do
        scripts_off
        open_page
        find_record("quarterly")
      end

      after { scripts_on }

      it "finds on the task's page" do
        expect(page).to have_current_path(%r{\A/admin/tasks/#{task.id}\?.*record_q=quarterly})
      end

      it "links the record I pick" do
        pick

        expect(linked.fetch("post").map(&:id)).to eq([post_record.id])
      end

      it "removes a link" do
        pick
        open_page
        click_button(remove_label)
        find(".toast", text: translate("tasks_page.toasts.record_unlinked"), visible: :all)

        expect(linked).to be_empty
      end
    end

    describe "a record linked since the page loaded" do
      before do
        open_task("Email the accountant")
        find_record("quarterly")
        Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "post", other_id: post_record.id })
        find(".record-picker-target", text: "Filing the quarterly taxes").click
      end

      it "says it is linked already beside the picker" do
        expect(find(".record-picker #task-#{task.id}-record-other-id-error"))
          .to have_text(translate("ui.components.record_links.field_error.other_id.taken"))
      end
    end
  end

  describe "deleting a task" do
    before { open_editor("Email the accountant") }

    it "asks with the confirmation text" do
      message = dismiss_confirm { click_button("Delete") }

      expect(message).to eq(translate("ui.views.tasks.edit.confirm_delete", task: "Email the accountant"))
    end

    it "keeps the task when I don't confirm", :aggregate_failures do
      dismiss_confirm { click_button("Delete") }

      expect(page).to have_no_css(".toast")
      expect(page).to have_field("task[title]", with: "Email the accountant")
    end

    it "deletes once I confirm" do
      accept_confirm { click_button("Delete") }

      expect(page).to have_css(".toast", text: "Task deleted")
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Admin task row actions", type: :feature do
  let(:repo) { Tasks::Slice["repos.task_queries"] }
  let(:sprint) { Tasks::Slice["repos.sprint_queries"].on(today) || create(:sprint, sprint_date: today) }

  def complete(title)
    within(row(title)) do
      find("summary[aria-keyshortcuts='x']").click
      click_button(admin_t("ui.components.tasks.complete_form.complete"))
    end
  end

  def item(selector, text) = find(selector, text:).tap(&:hover)

  def keep_page = execute_script("window.kept = true")

  def kept_dialog? = evaluate_script("document.querySelector('dialog[data-palette]').open")

  def kept_page? = evaluate_script("window.kept === true")

  def move(title, side) = row(title).find("button:has(.fa-arrow-#{side})").click

  def press(*keys) = page.driver.browser.keyboard.type(*keys)

  def row(title) = find(".task-title", exact_text: title).ancestor(".task").tap(&:hover)

  before { sign_in_to_admin }

  describe "starting a task" do
    before { create(:task, :in_sprint, sprint_id: sprint.id, title: "Ship it") }

    ["/admin", "/admin/tasks?filter=today"].each do |screen|
      describe "on #{screen}" do
        before do
          visit screen
          keep_page
          row("Ship it").click_button(admin_t("ui.components.tasks.controls.start"))
        end

        it "switches it to pause with no page load", :aggregate_failures do
          expect(page).to have_css(".toast", text: admin_t("tasks_page.toasts.started"))
          expect(row("Ship it")).to have_button(admin_t("ui.components.tasks.controls.stop"))
          expect(kept_page?).to be(true)
        end
      end
    end

    describe "with the page scrolled and the button focused" do
      before do
        page.driver.resize(1024, 300)
        visit "/admin/tasks?filter=today"
        execute_script(<<~JS, row("Ship it").find_button(admin_t("ui.components.tasks.controls.start")))
          arguments[0].focus();
          window.scrollTo(0, 120);
          window.scrolled = window.scrollY;
          arguments[0].click();
        JS
        find(".toast", text: admin_t("tasks_page.toasts.started"))
      end

      it "keeps the scroll" do
        expect(evaluate_script("window.scrolled > 0 && window.scrollY === window.scrolled")).to be(true)
      end

      it "keeps the focus in the row" do
        expect(evaluate_script("document.activeElement.closest('.task')?.textContent")).to include("Ship it")
      end
    end

    describe "with the palette open" do
      before do
        visit "/admin/tasks?filter=today"
        press([:meta, "/"])
        find("dialog[data-palette][open]")
        execute_script(<<~JS)
          document.querySelector(".task form[data-task-act='start']").requestSubmit();
        JS
        find(".toast", text: admin_t("tasks_page.toasts.started"))
      end

      it "keeps it open" do
        expect(kept_dialog?).to be(true)
      end
    end

    describe "from the keyboard" do
      before do
        visit "/admin/tasks?filter=today"
        keep_page
        press("j", "s")
        find(".toast", text: admin_t("tasks_page.toasts.started"))
        press("j", "x")
      end

      it "still takes key shortcuts after the update, closing the running task at once", :aggregate_failures do
        expect(page).to have_css(".toast", text: admin_t("tasks_page.toasts.completed"))
        expect(open_tasks).to be_empty
        expect(kept_page?).to be(true)
      end
    end

    describe "from next with its live change arriving before it lands" do
      before do
        create(:task, title: "Plan it")
        visit "/admin/tasks?filter=next"
        landing = request_gate.hold("/admin/tasks")
        row("Plan it").click_button(admin_t("ui.components.tasks.controls.start"))
        landing.wait_for_arrival
        sleep 1
        landing.release
        find(".toast", text: admin_t("tasks_page.toasts.started"))
        sleep 1
      end

      it "asks for no refresh and keeps the list it landed on", :aggregate_failures do
        expect(request_gate.answered("/admin/tasks")).to eq(2)
        expect(page).to have_css(".task-tabs [aria-current]", text: "today")
        expect(row("Plan it")).to have_button(admin_t("ui.components.tasks.complete_form.complete"))
      end
    end
  end

  describe "pulling a task from a pool" do
    before do
      create(:task, title: "Email the accountant")
      visit "/admin"
      keep_page
      item("[data-pools] .li", "Email the accountant").click_button(admin_t("ui.components.tasks.pools.pull"))
    end

    it "moves it into the sprint with no page load", :aggregate_failures do
      expect(page).to have_css(".toast", text: admin_t("tasks_page.toasts.moved"))
      expect(find("[data-sprint-panel]")).to have_css(".task-title", text: "Email the accountant")
      expect(kept_page?).to be(true)
    end
  end

  describe "acting on a running task" do
    let!(:task) { create(:task, :in_progress, :in_sprint, sprint_id: sprint.id, title: "Ship it") }

    before do
      visit "/admin/tasks?filter=today"
      keep_page
    end

    it "pauses it in place", :aggregate_failures do
      row("Ship it").click_button(admin_t("ui.components.tasks.controls.stop"))

      expect(page).to have_css(".toast", text: admin_t("tasks_page.toasts.stopped"))
      expect(row("Ship it")).to have_button(admin_t("ui.components.tasks.controls.start"), visible: :all)
      expect(kept_page?).to be(true)
    end

    it "completes it in place", :aggregate_failures do
      complete("Ship it")

      expect(page).to have_css(".toast", text: admin_t("tasks_page.toasts.completed"))
      expect(kept_page?).to be(true)
      expect(repo.by_id(task.id)).to be_done
    end
  end

  describe "acting on an open task" do
    let!(:task) { create(:task, title: "Write the brief") }

    before do
      visit "/admin/tasks?filter=next"
      keep_page
    end

    it "cancels it in place after asking", :aggregate_failures do
      confirm_yes { row("Write the brief").click_button(admin_t("ui.components.tasks.controls.cancel")) }

      expect(page).to have_css(".toast", text: admin_t("tasks_page.toasts.canceled"))
      expect(kept_page?).to be(true)
      expect(repo.by_id(task.id)).to be_canceled
    end

    it "completes it in place without asking for time", :aggregate_failures do
      complete("Write the brief")

      expect(page).to have_css(".toast", text: admin_t("tasks_page.toasts.completed"))
      expect(kept_page?).to be(true)
      expect(repo.by_id(task.id)).to be_done
    end

    it "moves it right in place", :aggregate_failures do
      move("Write the brief", "right")

      expect(page).to have_css(".toast", text: admin_t("tasks_page.toasts.moved"))
      expect(page).to have_current_path("/admin/tasks?filter=someday")
      expect(page).to have_css(".task", text: "Write the brief")
      expect(kept_page?).to be(true)
    end

    it "moves it left in place", :aggregate_failures do
      move("Write the brief", "left")

      expect(page).to have_css(".toast", text: admin_t("tasks_page.toasts.moved"))
      expect(page).to have_current_path("/admin/tasks?filter=today")
      expect(page).to have_css(".task", text: "Write the brief")
      expect(kept_page?).to be(true)
    end

    it "shows the error toast and leaves the page as it was when the action fails", :aggregate_failures do
      Tasks::Slice["operations.delete_task"].call(task.id)
      move("Write the brief", "right")

      expect(page).to have_css(".toast-failed", text: admin_t("ui.layouts.application.morph_failed"))
      expect(page).to have_css(".task", text: "Write the brief")
      expect(kept_page?).to be(true)
    end
  end

  describe "reopening a closed task" do
    before do
      create(:task, :done, title: "Filed the taxes")
      visit "/admin/tasks?filter=completed"
      keep_page
      row("Filed the taxes").click_button(admin_t("ui.components.tasks.controls.reopen"))
    end

    it "reopens it in place from its hover bar", :aggregate_failures do
      expect(page).to have_css(".toast", text: admin_t("tasks_page.toasts.reopened"))
      expect(kept_page?).to be(true)
    end
  end

  describe "scheduling a task into an upcoming sprint" do
    let(:later) { today + 3 }

    before do
      create(:sprint, sprint_date: later)
      create(:task, title: "Plan the trip")
      visit "/admin/tasks?filter=upcoming"
      keep_page
      find(".sprint-pull summary").click
      item(".sprint-pull .li", "Plan the trip").click_button(admin_t("ui.components.tasks.upcoming_sprints.pull_in"))
    end

    it "schedules it in place", :aggregate_failures do
      date = Admin::Slice["i18n"].l(later, format: :medium)

      expect(page).to have_css(".toast", text: admin_t("tasks_page.toasts.scheduled", date:))
      expect(kept_page?).to be(true)
    end
  end

  describe "a create form" do
    before do
      visit "/admin/tasks?filter=next"
      keep_page
      click_link("Create Task")
      within("dialog[open]") do
        fill_in("task[title]", with: "Ship the screen")
        click_button("Create task")
      end
    end

    it "still posts and loads the page", :aggregate_failures do
      expect(page).to have_css(".toast", text: admin_t("tasks_page.toasts.captured"))
      expect(kept_page?).to be(false)
    end
  end
end

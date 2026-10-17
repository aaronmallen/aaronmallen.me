# frozen_string_literal: true

RSpec.describe "Admin row context menu", type: :feature do
  let(:repo) { Tasks::Slice["repos.task_queries"] }
  let(:task) { create(:task, title: "Ship it") }

  def active_text = evaluate_script("document.activeElement.textContent.trim()")

  def focus_row(title) = execute_script("arguments[0].focus()", find(".task-title", exact_text: title))

  def item(label) = menu.first(".ctx-item", text: label)

  def keep_page = execute_script("window.kept = true")

  def kept_page? = evaluate_script("window.kept === true")

  def menu = find("[data-context-menu]")

  def menu_box
    evaluate_script("JSON.parse(JSON.stringify(document.querySelector('[data-context-menu]').getBoundingClientRect()))")
  end

  def open_menu(title = "Ship it") = row(title).find(".record-key").right_click

  def press(*keys) = page.driver.browser.keyboard.type(*keys)

  def press_menu_key
    %w[keyDown keyUp].each do |type|
      page.driver.browser.page.command(
        "Input.dispatchKeyEvent", type:, key: "ContextMenu", code: "ContextMenu", windowsVirtualKeyCode: 93,
      )
    end
  end

  def row(title) = find(".task-title", exact_text: title).ancestor(".task")

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  def watch_menus = execute_script(<<~JS)
    window.prevented = [];
    window.addEventListener("contextmenu", (event) => window.prevented.push(event.defaultPrevented));
  JS

  before do
    sign_in_to_admin
    task
  end

  describe "right-clicking a task row" do
    before do
      page.driver.resize(1280, 1600)
      visit "/admin/tasks?filter=next"
      watch_menus
      execute_script(<<~JS)
        window.addEventListener("contextmenu", (event) => { window.pointer = [event.clientX, event.clientY]; });
      JS
      open_menu
    end

    it "opens the menu at the pointer", :aggregate_failures do
      expect(menu).to have_css(".ctx-head", text: "#{task.number} · Ship it")
      expect([menu_box["left"], menu_box["top"]]).to eq(evaluate_script("window.pointer"))
      expect(evaluate_script("window.prevented")).to eq([true])
    end

    it "holds the actions an open task takes", :aggregate_failures do
      %w[Open Start Complete Schedule Tags Copy Delete].each { expect(menu).to have_css(".ctx-label", text: it) }
      expect(menu).to have_no_css(".ctx-label", text: "Reopen")
    end

    it "keeps admin keys quiet while it is open" do
      press("s")

      expect(page).to have_no_css(".toast", wait: 0.5)
    end

    it "closes when I click elsewhere" do
      first("h1, .page-head").click

      expect(page).to have_no_css("[data-context-menu]")
    end
  end

  describe "the browser's own menu" do
    before do
      visit "/admin/tasks?filter=next"
      watch_menus
    end

    it "shows on shift and right-click", :aggregate_failures do
      row("Ship it").find(".record-key").right_click(:shift)

      expect(evaluate_script("window.prevented")).to eq([false])
      expect(page).to have_no_css("[data-context-menu]", wait: 0.5)
    end

    it "shows on a right-click on a link in the row", :aggregate_failures do
      find(".task-title", exact_text: "Ship it").right_click

      expect(evaluate_script("window.prevented")).to eq([false])
      expect(page).to have_no_css("[data-context-menu]", wait: 0.5)
    end
  end

  describe "from the keyboard" do
    before { visit "/admin/tasks?filter=next" }

    [["the Menu key", -> { press_menu_key }], ["Shift+F10", -> { press(%i[shift f10]) }]].each do |name, keys|
      describe "on #{name}" do
        before do
          focus_row("Ship it")
          instance_exec(&keys)
          menu
        end

        it "opens beside the row" do
          box = row("Ship it").evaluate_script("JSON.parse(JSON.stringify(this.getBoundingClientRect()))")

          expect(menu_box["left"]).to be_within(1).of(box["left"] + 24)
        end

        it "focuses the first item" do
          expect(active_text).to include("Open")
        end
      end
    end

    describe "moving through it" do
      before do
        focus_row("Ship it")
        press_menu_key
        menu
      end

      it "steps with the arrow keys" do
        press(:down)

        expect(active_text).to include("Start")
      end

      it "opens a submenu with the right arrow and leaves it with the left", :aggregate_failures do
        press(:down) until active_text.include?(translate("ui.components.tasks.menu_plan.move"))
        press(:right)
        expect(active_text).to include("Today")

        press(:left)
        expect(active_text).to include(translate("ui.components.tasks.menu_plan.move"))
      end

      it "runs an item on Enter" do
        press(:down, :enter)

        expect(page).to have_css(".toast", text: translate("tasks_page.toasts.started"))
      end

      it "closes on Escape and hands focus back to the row", :aggregate_failures do
        press(:escape)

        expect(page).to have_no_css("[data-context-menu]")
        expect(evaluate_script("document.activeElement.closest('.task')?.textContent")).to include("Ship it")
      end
    end
  end

  describe "starting a task" do
    let(:task) do
      sprint = Tasks::Slice["repos.sprint_queries"].on(Blog::TimeZone.today) || create(:sprint, sprint_date: Blog::TimeZone.today)
      create(:task, :in_sprint, sprint_id: sprint.id, title: "Ship it")
    end

    before do
      visit "/admin/tasks?filter=today"
      keep_page
      open_menu
      item("Start").click
    end

    it "switches its row to pause with no page load", :aggregate_failures do
      expect(page).to have_css(".toast", text: translate("tasks_page.toasts.started"))
      expect(row("Ship it")).to have_button(translate("ui.components.tasks.controls.stop"), visible: :all)
      expect(kept_page?).to be(true)
    end
  end

  describe "tags" do
    let(:tagged) { [] }

    before do
      create(:tag, :private, name: "home", color: "mk-blue")
      create(:tag, :private, name: "homework", color: "mk-pink")
      create(:tag, name: "ruby")
      Tasks::Slice["repos.task_mutations"].replace_tags(task.id, tagged)
      visit "/admin/tasks?filter=next"
      open_menu
      item("Tags").hover
    end

    it "lists only private tags, read as checkboxes", :aggregate_failures do
      expect(menu).to have_css("[role=menuitemcheckbox][aria-checked=false]", text: "#home")
      expect(menu).to have_no_text("#ruby")
    end

    it "tags the task on a tick", :aggregate_failures do
      item("#home").click

      expect(page).to have_css(".toast", text: "Tagged 1 task home")
      expect(repo.by_id(task.id).tags.map(&:name)).to eq(["home"])
    end

    describe "with the tag on" do
      let(:tagged) { ["home"] }

      it "untags the task on an untick", :aggregate_failures do
        item("#home").click

        expect(page).to have_css(".toast", text: "Took home off 1 task")
        expect(repo.by_id(task.id).tags).to be_empty
      end
    end

    it "makes a new tag" do
      menu.find(".ctx-input").send_keys("Errands", :enter)

      expect(page).to have_css(".toast", text: "Tagged 1 task errands")
    end

    describe "typing in the new tag box" do
      def box = menu.find(".ctx-input")

      def suggestions = menu.all(".ctx-suggest [role=menuitem]").map(&:text)

      before { box.send_keys("hom") }

      it "suggests the tags that match, each in its color", :aggregate_failures do
        expect(suggestions).to eq(%w[#home #homework])
        expect(menu).to have_css(".ctx-suggest .tag.pink", text: "#homework")
      end

      it "applies a picked tag" do
        menu.find(".ctx-suggest [role=menuitem]", text: "#homework").click

        expect(page).to have_css(".toast", text: "Tagged 1 task homework")
      end

      it "picks by keyboard alone", :aggregate_failures do
        press(:down, :down, :up, :enter)

        expect(page).to have_css(".toast", text: "Tagged 1 task home")
        expect(repo.by_id(task.id).tags.map(&:name)).to eq(["home"])
      end

      it "closes the suggestions on Escape and keeps the menu", :aggregate_failures do
        box.send_keys(:escape)

        expect(menu).to have_no_css(".ctx-suggest [role=menuitem]")
        expect(evaluate_script("document.activeElement.classList.contains('ctx-input')")).to be(true)
      end

      it "passes axe" do
        expect(axe_breaches).to eq([])
      end
    end

    it "refuses a bad name with an error toast", :aggregate_failures do
      menu.find(".ctx-input").send_keys("no good", :enter)

      expect(page).to have_css(".toast-failed", text: translate("bulk_refusals.tag_format"))
      expect(repo.by_id(task.id).tags).to be_empty
    end
  end

  describe "deleting" do
    before do
      visit "/admin/tasks?filter=next"
      open_menu
      item("Delete").click
    end

    it "asks for a second click", :aggregate_failures do
      expect(item(translate("ui.views.tasks.menu.confirm_delete"))).to be_truthy
      expect(repo.by_id(task.id)).not_to be_nil
    end

    it "deletes nothing on Escape", :aggregate_failures do
      press(:escape)

      expect(page).to have_no_css("[data-context-menu]")
      expect(repo.by_id(task.id)).not_to be_nil
    end

    it "deletes on the second click" do
      item(translate("ui.views.tasks.menu.confirm_delete")).click

      expect(page).to have_css(".toast", text: translate("tasks_page.toasts.deleted"))
    end
  end

  describe "copying" do
    before do
      visit "/admin/tasks?filter=next"
      watch_clipboard
      open_menu
      item("Copy").hover
      item("Title").click
    end

    it "puts the text on the clipboard and shows a toast", :aggregate_failures do
      expect(page).to have_css(".toast", text: translate("ui.views.tasks.menu.copied_title"))
      expect(evaluate_script("window.copiedKeys")).to eq(["Ship it"])
    end
  end

  describe "near the edge of the window" do
    before do
      page.driver.resize(400, 500)
      visit "/admin/tasks?filter=next"
      execute_script(<<~JS, row("Ship it"))
        arguments[0].dispatchEvent(new MouseEvent("contextmenu", {
          bubbles: true, cancelable: true, button: 2, clientX: innerWidth - 4, clientY: innerHeight - 4,
        }));
      JS
      menu
    end

    it "stays fully on screen", :aggregate_failures do
      expect(menu_box["right"]).to be <= evaluate_script("innerWidth")
      expect(menu_box["bottom"]).to be <= evaluate_script("innerHeight")
    end

    it "makes items 44px tall" do
      expect(evaluate_script("document.querySelector('.ctx-item').getBoundingClientRect().height")).to be >= 44
    end
  end

  describe "the sprint pool and the calendar" do
    it "opens from a pool row on Today" do
      visit "/admin"
      find("[data-pools] .li", text: "Ship it").right_click

      expect(menu).to have_css(".ctx-head", text: "Ship it")
    end
  end

  describe "a live update" do
    let(:events) { "/admin/events" }

    before do
      visit "/admin/tasks?filter=next"
      Timeout.timeout(5) { sleep 0.05 until request_gate.answered(events) >= 1 }
      open_menu
      menu
      create(:task, title: "Arrived live")
    end

    it "waits until the menu closes", :aggregate_failures do
      expect(page).to have_no_css(".task-title", text: "Arrived live", wait: 1)

      press(:escape)

      expect(page).to have_css(".task-title", text: "Arrived live")
    end
  end
end

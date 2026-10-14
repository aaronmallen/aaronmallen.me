# frozen_string_literal: true

RSpec.describe "Admin task drawer", type: :feature do
  let(:repo) { Tasks::Slice["repos.task_queries"] }
  let!(:task) { create(:task, title: "Clear the gutters", tags: %w[home]) }
  let(:other) { create(:task, title: "Buy a ladder") }

  def box(selector) = evaluate_script("(r => ({ top: r.top, bottom: r.bottom }))(#{selector}.getBoundingClientRect())")

  def controls(blocks = ".task-drawer-head, .task-drawer-foot")
    evaluate_script(<<~JS)
      [...document.querySelectorAll("#task-panel :is(#{blocks}) :is(a, button, summary)")]
        .filter((control) => control.checkVisibility())
        .map((control) => { const r = control.getBoundingClientRect(); return [r.width, r.height]; })
    JS
  end

  def open_task(title)
    find(".task-title", exact_text: title).click
    panel.assert_selector("h1", exact_text: title)
    settle("#task-panel")
  end

  def panel = find("dialog#task-panel[open]")

  def scroll(selector, to:) = execute_script("(s => { s.scrollTop = #{to}; })(#{selector})")

  def sideways?(selector) = evaluate_script("(d => d.scrollWidth > d.clientWidth)(#{selector})")

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  before do
    12.times { create(:task_comment, task_id: task.id, body: "note #{it}\n\n#{'Long line. ' * 40}") }
    sign_in_to_admin
    visit "/admin/tasks?filter=next"
  end

  describe "a long task" do
    let(:scroller) { "document.querySelector('[data-task-panel-body]')" }

    before do
      open_task("Clear the gutters")
      scroll(scroller, to: "s.scrollHeight")
    end

    it "keeps the header and the footer in view while the body scrolls", :aggregate_failures do
      body = box(scroller)

      expect(box("document.querySelector('#task-panel .task-drawer-head')")["top"]).to be_within(1).of(body["top"])
      expect(box("document.querySelector('#task-panel .task-drawer-foot')")["bottom"])
        .to be_within(1).of(body["bottom"])
    end
  end

  describe "Delete" do
    before do
      open_task("Clear the gutters")
      panel.find(".task-drawer-foot").click_button(translate("ui.views.tasks.show.delete"))
    end

    it "asks first" do
      key = task.number.to_s

      expect(confirm_ask).to have_text(translate("ui.views.tasks.show.confirm_delete", key:))
    end

    it "deletes the task and closes the drawer once I say yes", :aggregate_failures do
      confirm_yes

      expect(page).to have_css(".toast", text: translate("tasks_page.toasts.deleted"))
      expect(page).to have_no_css("dialog#task-panel[open]")
      expect(repo.by_id(task.id)).to be_nil
    end
  end

  describe "moving to another task" do
    before do
      create(:task_link, from_task_id: other.id, to_task_id: task.id)
      visit "/admin/tasks?filter=next"
      open_task("Clear the gutters")
      panel.click_link("Buy a ladder")
      panel.assert_selector("h1", exact_text: "Buy a ladder")
    end

    it "swaps the header" do
      expect(panel.find(".task-drawer-head .record-key")).to have_text(other.number.to_s, exact: true)
    end

    it "swaps the footer" do
      expect(panel.find(".task-drawer-foot form")["action"]).to end_with("/admin/tasks/#{other.id}/delete")
    end
  end

  describe "on a phone" do
    before do
      create(:work_session, :closed, task_id: task.id, started_at: Time.now - 3600)
      create(:task_event, task_id: task.id, kind: "tagged", tag_name: "home")
      page.driver.resize(375, 800)
      open_task("Clear the gutters")
    end

    it "gives every header and footer control a tap square" do
      expect(controls).to all(satisfy { |width, height| width >= 44 && height >= 44 })
    end

    it "gives the status bar, the notes and the facts a tap height", :aggregate_failures do
      found = controls(".task-stbar, .task-read-empty, .task-facts")

      expect(found.size).to be >= 4
      expect(found).to all(satisfy { |_, height| height >= 44 })
    end

    it "gives Time worked, the comments and the timeline a tap height", :aggregate_failures do
      panel.find(".task-timeline > summary").click
      found = controls(".task-session, .task-comments, .task-timeline")

      expect(found.size).to be >= 4
      expect(found).to all(satisfy { |_, height| height >= 44 })
    end

    it "lays the timeline out in one column" do
      panel.find(".task-timeline > summary").click

      expect(evaluate_script(<<~JS)).to eq(1)
        getComputedStyle(document.querySelector("#task-panel .timeline-event")).gridTemplateColumns.split(" ").length
      JS
    end

    it "does not scroll sideways", :aggregate_failures do
      expect(sideways?("document.documentElement")).to be(false)
      expect(sideways?("document.querySelector('[data-task-panel-body]')")).to be(false)
    end
  end

  describe "the task's own page" do
    before do
      visit "/admin/tasks/#{task.id}"
      scroll("document.scrollingElement", to: 600)
    end

    it "keeps the header under the top bar and the footer at the bottom", :aggregate_failures do
      top_bar = box("document.querySelector('.top-bar')")

      expect(box("document.querySelector('main .task-drawer-head')")["top"]).to be_within(1).of(top_bar["bottom"])
      expect(box("document.querySelector('main .task-drawer-foot')")["bottom"])
        .to be_within(1).of(evaluate_script("window.innerHeight"))
    end
  end
end

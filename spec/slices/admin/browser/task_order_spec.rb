# frozen_string_literal: true

RSpec.describe "Admin task order", type: :feature do
  let(:repo) { Tasks::Slice["repos.task_repo"] }

  def center(element)
    box = evaluate_script(<<~JS, element)
      (r => ({ x: r.left + r.width / 2, y: r.top + r.height / 2 }))(arguments[0].getBoundingClientRect())
    JS

    { x: box["x"], y: box["y"] }
  end

  def drag(title, below:)
    start, *steps = stroke(title, below)
    mouse = page.driver.browser.mouse

    mouse.move(**start).down
    steps.each { mouse.move(**it) }
    mouse.up
  end

  def grip(title) = row(title).find("[data-task-grip]")

  def grip_box
    evaluate_script(<<~JS)
      (r => ({ width: r.width, height: r.height }))(document.querySelector("[data-task-grip]").getBoundingClientRect())
    JS
  end

  def listed(list = "next") = repo.in_list(list).map(&:title)

  def nudge(title, key)
    execute_script("arguments[0].focus()", row(title).find(".task-title"))
    page.driver.browser.keyboard.type([:alt, key])
  end

  def place_path(title = "first") = "/admin/tasks/#{repo.all_open.find { it.title == title }.id}/place"

  def row(title) = find(".task", text: title)

  def shown = page.all(".task-title").map(&:text)

  def stroke(title, below)
    execute_script("arguments[0].scrollIntoView({ block: 'center' })", grip(title))
    from = center(grip(title))
    to = center(row(below))

    (0..6).map { { x: from[:x], y: from[:y] + ((to[:y] + 10 - from[:y]) * it / 6) } }
  end

  def touch(type, point)
    page.driver.browser.page.command("Input.dispatchTouchEvent", type:, touchPoints: point ? [point] : [])
  end

  def touch_drag(title, below:, finish: "touchEnd")
    start, *steps = stroke(title, below)

    touch("touchStart", start)
    steps.each { touch("touchMove", it) }
    touch(finish, nil)
  end

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  def wait_for_save(count = 1, title: "first")
    path = place_path(title)
    Timeout.timeout(5) { sleep 0.05 until request_gate.answered(path) >= count }
  end

  before do
    %w[first second third].each_with_index { |title, index| create(:task, title:, position: index + 1) }
    create(:task, :someday, title: "elsewhere")
    sign_in_to_admin
    visit "/admin/tasks?filter=next"
  end

  describe "a row" do
    it "shows a grip and no carets", :aggregate_failures do
      expect(page).to have_css(".task [data-task-grip]", count: 3)
      expect(page).to have_no_css(".task-order, .task-caret")
    end

    it "gives the grip a tap square on a phone", :aggregate_failures do
      page.driver.resize(390, 844)

      expect(grip_box["width"]).to be >= 44
      expect(grip_box["height"]).to be >= 44
    end

    it "fits a phone without scrolling the page sideways" do
      page.driver.resize(390, 844)

      expect(evaluate_script("(d => d.scrollWidth > d.clientWidth)(document.documentElement)")).to be(false)
    end
  end

  describe "dragging with a mouse" do
    before { drag("first", below: "third") }

    it "moves the row at once" do
      expect(shown).to eq(%w[second third first])
    end

    it "saves the new order", :aggregate_failures do
      wait_for_save

      expect(listed).to eq(%w[second third first])
      expect(listed("someday")).to eq(%w[elsewhere])
    end

    it "keeps the order on reload" do
      wait_for_save
      visit "/admin/tasks?filter=next"

      expect(shown).to eq(%w[second third first])
    end
  end

  describe "dragging with a finger on a phone" do
    before do
      page.driver.resize(390, 844)
      touch_drag("first", below: "second")
    end

    it "saves the new order" do
      wait_for_save

      expect(listed).to eq(%w[second first third])
    end
  end

  describe "a drag the browser cancels" do
    before do
      page.driver.resize(390, 844)
      touch_drag("first", below: "third", finish: "touchCancel")
    end

    it "puts the row back without saving", :aggregate_failures do
      expect(page).to have_no_css(".task-dragging")
      expect(shown).to eq(%w[first second third])
      expect(request_gate.count(place_path)).to eq(0)
    end
  end

  describe "the keys" do
    it "moves a task down a place on Alt+Down and saves it", :aggregate_failures do
      nudge("first", :down)
      wait_for_save

      expect(shown).to eq(%w[second first third])
      expect(listed).to eq(%w[second first third])
    end

    it "moves a task up a place on Alt+Up and saves it", :aggregate_failures do
      nudge("first", :down)
      wait_for_save
      nudge("first", :up)
      wait_for_save(2)

      expect(listed).to eq(%w[first second third])
    end

    it "keeps focus on the row it moved" do
      nudge("first", :down)

      expect(evaluate_script("document.activeElement.textContent.trim()")).to eq("first")
    end

    it "does nothing past the top", :aggregate_failures do
      nudge("first", :up)

      expect(shown).to eq(%w[first second third])
      expect(request_gate.count(place_path)).to eq(0)
    end
  end

  describe "a search" do
    before { visit "/admin/tasks?filter=next&q=i" }

    it "hides the grips" do
      expect(page).to have_no_css("[data-task-grip]", visible: :all)
    end

    it "leaves Alt+Down alone", :aggregate_failures do
      nudge("first", :down)

      expect(shown).to eq(%w[first third])
      expect(request_gate.count(place_path)).to eq(0)
    end
  end

  describe "a save that fails" do
    before do
      Tasks::Slice["operations.complete_task"].call(repo.in_list("next").find { it.title == "first" }.id)
      nudge("first", :down)
    end

    it "puts the row back", :aggregate_failures do
      expect(page).to have_css(".toast-failed")
      expect(shown).to eq(%w[first second third])
    end

    it "says the order did not save" do
      expect(page).to have_css(".toast-failed", text: translate("ui.components.tasks.grip.failed"))
    end
  end

  describe "a sprint" do
    before do
      soon = create(:sprint, sprint_date: today + 1)
      later = create(:sprint, sprint_date: today + 2)
      create(:task, :in_sprint, sprint_id: soon.id, title: "soon one", position: 1)
      create(:task, :in_sprint, sprint_id: soon.id, title: "soon two", position: 2)
      create(:task, :in_sprint, sprint_id: later.id, title: "later one", position: 3)
      visit "/admin/tasks?filter=upcoming"
    end

    def sprint_titles(title) = find(".card", text: title).all(".task-title").map(&:text)

    def sprints = [sprint_titles("soon two"), sprint_titles("later one")]

    it "keeps a dropped task in its own sprint", :aggregate_failures do
      drag("soon one", below: "later one")
      wait_for_save(title: "soon one")

      expect { sprints }.to eventually(eq([["soon two", "soon one"], ["later one"]]))
      expect(repo.all_open.find { it.title == "soon one" }.sprint_id)
        .to eq(repo.all_open.find { it.title == "soon two" }.sprint_id)
    end
  end
end

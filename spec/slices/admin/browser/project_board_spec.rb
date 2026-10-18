# frozen_string_literal: true

RSpec.describe "Admin project board", type: :feature do
  let(:project) { create(:project, name: "blog") }
  let(:task) { create(:task, title: "Write the brief") }

  def box(element)
    evaluate_script(<<~JS, element)
      (r => ({ x: r.left + r.width / 2, y: r.top + r.height / 2 }))(arguments[0].getBoundingClientRect())
    JS
  end

  def card = find(".kc", text: "Write the brief")

  def column(name) = find(".kcol.k-#{name}")

  def drag_to(name)
    from = box(card)
    mouse = page.driver.browser.mouse

    mouse.move(x: from["x"], y: from["y"]).down
    stroke(from, box(column(name))).each { mouse.move(**it) }
    mouse.up
  end

  def link(task) = Tasks::Slice["operations.set_task_project"].call(task.id, project.id)

  def stroke(from, to)
    (1..6).map do |step|
      { x: from["x"] + ((to["x"] - from["x"]) * step / 6), y: from["y"] + ((to["y"] - from["y"]) * step / 6) }
    end
  end

  before do
    sign_in_to_admin
    link(task)
    visit "/admin/projects/#{project.id}"
    keep_page
  end

  it "moves a card by its arrow in place", :aggregate_failures do
    card.hover
    card.find("button[aria-label='Move to ready']").click

    expect(page).to have_css(".kcol.k-ready .kc", text: "Write the brief")
    expect(page).to have_css(".toast", text: "Moved BLO-1 to ready")
    expect(kept_page?).to be(true)
  end

  it "moves a card from its menu in place", :aggregate_failures do
    card.right_click
    item("Board column").hover
    item("in progress").click

    expect(page).to have_css(".kcol.k-in_progress .kc", text: "Write the brief")
    expect(kept_page?).to be(true)
  end

  it "drags a card to another column in place", :aggregate_failures do
    drag_to("ready")

    expect(page).to have_css(".kcol.k-ready .kc", text: "Write the brief")
    expect(page).to have_css(".toast", text: "Moved BLO-1 to ready")
    expect(Tasks::Slice["repos.task_queries"].by_id(task.id).stage).to eq("ready")
    expect(kept_page?).to be(true)
  end

  it "starts a task dragged to in progress", :aggregate_failures do
    drag_to("in_progress")

    expect(page).to have_css(".kcol.k-in_progress .kc.doing", text: "Write the brief")
    expect(Tasks::Slice["repos.task_queries"].by_id(task.id).status).to eq("in_progress")
  end

  describe "a full column" do
    def backlog_cards = column("backlog").all(".kc").size

    before do
      override_setting(:board, :column_size, to: 1)
      link(create(:task, title: "Second brief"))
      visit "/admin/projects/#{project.id}"
      wait_for_stream
      keep_page
      click_button "Load more · 1 left"
    end

    it "loads more cards in place", :aggregate_failures do
      expect(column("backlog")).to have_css(".kc", count: 2)
      expect(page).to have_current_path("/admin/projects/#{project.id}?backlog=2")
      expect(kept_page?).to be(true)
    end

    it "keeps the grown column through a live refresh", :aggregate_failures do
      link(create(:task, stage: "ready", title: "Live brief"))

      expect(column("ready")).to have_css(".kc", text: "Live brief")
      expect(backlog_cards).to eq(2)
    end

    it "keeps the grown column through a reload", :aggregate_failures do
      expect(page).to have_current_path("/admin/projects/#{project.id}?backlog=2")
      visit current_url

      expect(column("backlog")).to have_css(".kc", count: 2)
    end
  end

  it "opens the task drawer from a card" do
    card.find(".kc-title").click

    expect(page).to have_css("dialog[data-task-panel][open]", text: "Write the brief")
  end
end

# frozen_string_literal: true

RSpec.describe "Project board views", type: :feature do
  def at(width) = page.current_window.resize_to(width, 900)

  def link_to(project, task)
    Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "project", other_id: project.id })
  end

  def shown
    [".board", ".board-list"].select { has_css?(it, wait: false) }.map { it.delete_prefix(".") }
  end

  def visit_board(query = nil) = visit(["/projects/sai", query].compact.join("?"))

  before do
    project = create(:project, name: "sai", board_published: true)
    link_to(project, create(:task, title: "A long title for a task that wraps on a narrow screen"))
    link_to(project, create(:task, :canceled, completed_at: Time.now - 60))
    visit "/"
    execute_script("localStorage.clear()")
  end

  describe "a switch" do
    before do
      at(1200)
      visit_board
      keep_page
      click_button "list"
    end

    it "shows the list without a reload", :aggregate_failures do
      expect(shown).to eq(%w[board-list])
      expect(kept_page?).to be(true)
    end

    it "presses its button and writes the param", :aggregate_failures do
      expect(page).to have_css(".board-switch button[aria-pressed='true']", exact_text: "list")
      expect(URI(current_url).query).to eq("view=list")
    end
  end

  [[1200, "list", %w[board-list]], [390, "board", %w[board]]].each do |width, view, views|
    it "shows the #{view} at #{width}px when the param asks" do
      at(width)
      visit_board("view=#{view}")

      expect(shown).to eq(views)
    end
  end

  it "keeps the last choice when no param asks" do
    at(1200)
    visit_board
    click_button "list"
    visit_board

    expect(shown).to eq(%w[board-list])
  end

  { 390 => %w[board-list], 700 => %w[board-list], 701 => %w[board], 1200 => %w[board] }.each do |width, views|
    it "shows #{views.first} at #{width}px with nothing saved" do
      at(width)
      visit_board

      expect(shown).to eq(views)
    end

    it "shows #{views.first} at #{width}px with script off", :aggregate_failures do
      at(width)
      visit_board
      execute_script("document.querySelector('[data-board-views]').removeAttribute('data-view')")

      expect(shown).to eq(views)
      expect(page).to have_no_css(".board-switch")
    end
  end

  describe "a group" do
    before do
      at(390)
      visit_board
    end

    it "closes from its header" do
      find(".board-group.backlog > summary").click

      expect(page).to have_no_css(".board-group.backlog .board-row")
    end

    it "starts canceled closed and opens it from its header", :aggregate_failures do
      expect(page).to have_no_css(".board-group.canceled .board-row")
      find(".board-group.canceled > summary").click

      expect(page).to have_css(".board-group.canceled .board-row")
    end
  end

  it "keeps the list inside a phone with tap targets of 44px", :aggregate_failures do
    at(390)
    visit_board
    sizes = evaluate_script(<<~JS)
      [...document.querySelectorAll('.board-switch button, .board-group > summary, .board-row')]
        .map((el) => el.getBoundingClientRect().height)
    JS

    expect(sizes.min).to be >= 44
    expect(evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
  end
end

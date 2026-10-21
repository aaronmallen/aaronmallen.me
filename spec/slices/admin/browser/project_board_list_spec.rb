# frozen_string_literal: true

RSpec.describe "Admin project board list", type: :feature do
  let(:project) { create(:project, name: "blog") }
  let(:board_path) { "/admin/projects/#{project.id}" }
  let!(:task) { create(:task, title: "Write the brief").tap { link(it) } }

  def board = find("[data-board-shows='board']", visible: :all)

  def box(element)
    evaluate_script(<<~JS, element).transform_keys(&:to_sym)
      (r => ({ x: r.left + r.width / 2, y: r.top + r.height / 2 }))(arguments[0].getBoundingClientRect())
    JS
  end

  def drag(element, onto)
    mouse = page.driver.browser.mouse
    from = box(element)

    mouse.move(**from).down
    stroke(from, box(onto)).each { mouse.move(**it) }
    mouse.up
  end

  def group(name) = find(".klg.k-#{name}")

  def link(task) = Tasks::Slice["operations.set_task_project"].call(task.id, project.id)

  def list = find("[data-board-shows='list']", visible: :all)

  def row = find(".kli", text: "Write the brief")

  def showing
    { board: board.visible?, list: list.visible? }
  end

  def stage = Tasks::Slice["repos.task_queries"].by_id(task.id).stage

  def stroke(from, to)
    (1..6).map do |step|
      { x: from[:x] + ((to[:x] - from[:x]) * step / 6), y: from[:y] + ((to[:y] - from[:y]) * step / 6) }
    end
  end

  def visit_board(query = "")
    visit "#{board_path}#{query}"
    keep_page
  end

  before do
    sign_in_to_admin
    visit board_path
    execute_script("localStorage.clear()")
  end

  after { page.current_window.resize_to(1280, 800) }

  describe "the toggle" do
    before { visit_board }

    it "shows the list in place and writes the param", :aggregate_failures do
      click_link "list"

      expect(page).to have_current_path("#{board_path}?view=list")
      expect(showing).to eq(board: false, list: true)
      expect(page).to have_css(".kb-view a.current[aria-current='page']", text: "list")
      expect(kept_page?).to be(true)
    end

    it "shows the board again in place", :aggregate_failures do
      click_link "list"
      click_link "board"

      expect(page).to have_current_path("#{board_path}?view=board")
      expect(showing).to eq(board: true, list: false)
      expect(kept_page?).to be(true)
    end

    it "keeps the choice for the next visit with no param" do
      click_link "list"
      visit board_path

      expect(showing).to eq(board: false, list: true)
    end

    it "lets the param beat the saved choice" do
      click_link "list"
      visit "#{board_path}?view=board"

      expect(showing).to eq(board: true, list: false)
    end
  end

  describe "with nothing saved" do
    it "shows the board above 700px wide" do
      visit_board

      expect(showing).to eq(board: true, list: false)
    end

    it "shows the list at 700px wide" do
      page.current_window.resize_to(700, 800)
      visit_board

      expect(showing).to eq(board: false, list: true)
    end
  end

  describe "with script off" do
    def unpicked
      execute_script("document.querySelector('[data-board-views]').removeAttribute('data-board-view')")
      showing
    end

    it "lets CSS show the list at 700px wide or less" do
      page.current_window.resize_to(700, 800)
      visit_board

      expect(unpicked).to eq(board: false, list: true)
    end

    it "lets CSS show the board above 700px wide" do
      page.current_window.resize_to(701, 800)
      visit_board

      expect(unpicked).to eq(board: true, list: false)
    end
  end

  describe "the list" do
    before { visit_board("?view=list") }

    it "moves a task with its column picker in place", :aggregate_failures do
      row.find("select[name=to]").select("ready")

      expect(group("ready")).to have_css(".kli", text: "Write the brief")
      expect(page).to have_css(".toast", text: "Moved BLO-1 to ready")
      expect(showing).to eq(board: false, list: true)
      expect(kept_page?).to be(true)
    end

    it "moves a task dragged onto another group", :aggregate_failures do
      drag(row.find(".task-title"), group("ready").find("summary"))

      expect(group("ready")).to have_css(".kli", text: "Write the brief")
      expect(page).to have_css(".toast", text: "Moved BLO-1 to ready")
      expect(stage).to eq("ready")
      expect(kept_page?).to be(true)
    end

    it "folds a group from its header", :aggregate_failures do
      group("backlog").find("summary").click

      expect(group("backlog")).to have_no_css(".kli")
      group("backlog").find("summary").click
      expect(group("backlog")).to have_css(".kli", text: "Write the brief")
    end

    it "opens the canceled group from its header" do
      create(:task, :canceled, title: "Dropped").tap { link(it) }
      visit_board("?view=list")
      group("canceled").find("summary").click

      expect(group("canceled")).to have_css(".kli", text: "Dropped")
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Admin project board list", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:project) { create(:project, name: "blog") }
  let(:board_path) { "/admin/projects/#{project.id}" }

  def days_ago(days) = now - (days * 86_400)

  def group(name) = page.find(".kb-list section.klg.k-#{name}")

  def link(task) = Tasks::Slice["operations.set_task_project"].call(task.id, project.id)

  def linked(*traits, **attributes) = create(:task, *traits, **attributes).tap { link(it) }

  def picker(task) = page.find("form.kls[action='#{board_path}/tasks/#{task.id}/move']")

  def titles(name) = group(name).all(".kli .task-title", visible: :all).map { it.text(:all) }

  def toggle_links = page.all(".kb-meta > .kb-view .seg a.seg-option")

  before { sign_in_to_admin }

  describe "the page" do
    before do
      linked(title: "Plan it")
      linked(title: "Ready it", stage: "ready")
      linked(:in_progress, title: "Do it")
      linked(:done, title: "Ship it")
      linked(:canceled, title: "Drop it")
      get board_path
    end

    it "draws the board and the list, and leaves the pick to the browser", :aggregate_failures do
      expect(page).to have_css(".kb-views[data-board-views]:not([data-board-view])")
      expect(page).to have_css(".kb-views > [data-board-shows='board'] .kb")
      expect(page).to have_css(".kb-views > [data-board-shows='list'] .kls3")
    end

    it "offers a board and a list link after the facts" do
      expect(toggle_links.map { [it.text.strip, it[:href], it[:"data-board-pick"]] })
        .to eq([["board", "#{board_path}?view=board", "board"], ["list", "#{board_path}?view=list", "list"]])
    end

    it "draws each link's icon" do
      expect(page.all(".kb-view a.seg-option i", visible: :all).map { it[:class] })
        .to eq(["fa-solid table-columns", "fa-solid list"])
    end

    it "marks neither link until the browser picks" do
      expect(page).to have_no_css(".kb-view .current")
    end

    it "draws one group per column, in column order, with its label and count", :aggregate_failures do
      expect(page.all(".kls3 > section.klg h2").map(&:text)).to eq(["backlog", "ready", "in progress", "done",
                                                                    "canceled"])
      expect(page.all(".kls3 > section.klg .kcol-count").map(&:text)).to eq(%w[1 1 1 1 1])
      expect(Blog::Types::TaskColumn.values.map { titles(it) })
        .to eq([["Plan it"], ["Ready it"], ["Do it"], ["Ship it"], ["Drop it"]])
    end

    it "folds each group from its header and starts canceled closed", :aggregate_failures do
      expect(page.all(".kls3 details[open] > summary.klh h2").map(&:text))
        .to eq(["backlog", "ready", "in progress", "done"])
      expect(group("canceled")).to have_css("details:not([open]) > summary.klh", visible: :all)
    end

    it "marks each group as a drop target for its column" do
      expect(page.all(".kls3 > section[data-board-column]").map { it[:"data-board-column"] })
        .to eq(Blog::Types::TaskColumn.values)
    end

    it "explains both ways to move a task" do
      expect(page).to have_css(".kb-list > p.hint", text: Admin::Slice["i18n"].t("ui.components.projects.board_list.hint"))
    end

    it "reuses the task row with no reorder grip", :aggregate_failures do
      expect(group("backlog")).to have_css(".kli[data-board-card] > .task[data-key-row] a.task-title", text: "Plan it")
      expect(page).to have_no_css(".kli [data-task-grip]", visible: :all)
    end

    it "fetches a row's menu with the board's project" do
      expect(group("backlog")).to have_css(".task[data-menu*='project=#{project.id}']")
    end

    it "sends a row's actions back to the board" do
      values = group("in_progress").all(".task form input[name=return_to]", visible: :all).map(&:value).uniq

      expect(values).to eq([board_path])
    end
  end

  describe "the column picker" do
    let!(:task) { linked(title: "Plan it") }

    before { get board_path }

    it "posts to the board's move by fetch and morph", :aggregate_failures do
      expect(picker(task)[:method]).to eq("post")
      expect(picker(task)).to have_css("input[name=return_to][value='#{board_path}']", visible: :all)
      expect(picker(task)[:"data-morph"]).not_to be_nil
      expect(picker(task)[:"data-autosubmit"]).not_to be_nil
    end

    it "lists every column with the task's own picked", :aggregate_failures do
      select = picker(task).find("select[name=to]")

      expect(select.all("option").map(&:value)).to eq(Blog::Types::TaskColumn.values)
      expect(select.find("option[selected]").value).to eq("backlog")
      expect(picker(task)).to have_css("label", text: "Column for BLO-1")
    end

    it "offers a Move button for a browser with script off" do
      expect(picker(task).find("noscript", visible: :all).native.inner_html).to include("Move")
    end

    it "moves the task and goes back to the board", :aggregate_failures do
      post "#{board_path}/tasks/#{task.id}/move", _csrf_token: admin_csrf_token, to: "done", return_to: board_path

      expect(last_response.location).to end_with(board_path)
      expect(Tasks::Slice["repos.task_queries"].by_id(task.id).status).to eq("done")
    end
  end

  describe "a picked view" do
    it "draws the list for ?view=list and marks its link", :aggregate_failures do
      get board_path, view: "list"

      expect(page).to have_css(".kb-views[data-board-view='list']")
      expect(page).to have_css(".kb-view a.seg-option.current[aria-current='page']", text: "list")
    end

    it "draws the board for ?view=board" do
      get board_path, view: "board"

      expect(page).to have_css(".kb-views[data-board-view='board']")
    end

    it "leaves an unknown view to the browser" do
      get board_path, view: "grid"

      expect(page).to have_css(".kb-views:not([data-board-view])")
    end

    it "keeps the grown columns in the view links" do
      get board_path, backlog: 40

      expect(page.find(".kb-view a", text: "list")[:href]).to eq("#{board_path}?backlog=40&view=list")
    end
  end

  describe "a full group" do
    def more(name) = group(name).find("form[data-autosubmit][method='get']")

    before do
      override_setting(:board, :column_size, to: 2)
      3.times { linked(title: "Plan #{it}") }
      2.times { linked(stage: "ready", title: "Ready #{it}") }
    end

    it "shows the cap and offers the rest in its own Load More", :aggregate_failures do
      get board_path

      expect(titles("backlog").size).to eq(2)
      expect(more("backlog")).to have_button("Load more · 1 left")
      expect(group("ready")).to have_no_css("form[data-autosubmit][method='get']")
    end

    it "grows only that group" do
      get board_path

      expect(more("backlog").all("input[type=hidden]", visible: :all).to_h { [it[:name], it.value] })
        .to eq("backlog" => "4")
    end

    it "shows the grown group whole" do
      get board_path, backlog: 4

      expect(titles("backlog").size).to eq(3)
    end
  end

  describe "an old closed task" do
    before do
      linked(:done, title: "Shipped", completed_at: days_ago(14))
      linked(:canceled, title: "Dropped", completed_at: days_ago(1))
      get board_path
    end

    it "leaves out a task closed 14 days ago or more", :aggregate_failures do
      expect(titles("done")).to be_empty
      expect(group("done")).to have_css(".kcol-empty", text: "No tasks")
    end

    it "keeps a task closed less than 14 days ago" do
      expect(titles("canceled")).to eq(["Dropped"])
    end
  end
end

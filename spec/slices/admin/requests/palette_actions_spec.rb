# frozen_string_literal: true

RSpec.describe "Admin palette actions", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def action(name) = group.find("#command-palette-#{name}", visible: :all)

  def actions = group.all("[data-palette-option]", visible: :all)

  def group = page.find("[aria-labelledby='command-palette-group-actions']", visible: :all)

  before { sign_in_to_admin }

  describe "the list as it ships" do
    before { get "/admin" }

    it "draws one row per entry, in order" do
      names = %w[
        create-task create-decision create-journal-entry new-post new-social-post plan-tomorrow import-commits
        sync-issues keyboard-shortcuts toggle-theme start-task complete-task pause-task
      ]

      expect(actions.map { it[:id] }).to eq(names.map { "command-palette-#{it}" })
    end

    it "sends Create task to the new task dialog, or its page without one", :aggregate_failures do
      row = action("create-task")

      expect(row["data-palette-dialog"]).to eq("task-create")
      expect(row["data-palette-href"]).to eq("/admin/tasks/new")
      expect(row).to have_css(".fa-list-check", visible: :all)
    end

    it "sends Create decision to the new decision form, with no dialog", :aggregate_failures do
      row = action("create-decision")

      expect(row["data-palette-dialog"]).to be_nil
      expect(row["data-palette-href"]).to eq("/admin/decisions/new")
      expect(row).to have_css(".pal-r-label", text: "Create decision")
      expect(row).to have_css(".fa-scale-balanced", visible: :all)
    end

    it "sends Create journal entry to the journal modal, or the journal page without one", :aggregate_failures do
      row = action("create-journal-entry")

      expect(row["data-palette-dialog"]).to eq("journal-write")
      expect(row["data-palette-href"]).to eq("/admin/journal?write=1")
      expect(row).to have_css(".fa-feather", visible: :all)
    end

    it "draws no row with a plus" do
      expect(group).to have_no_css(".fa-plus", visible: :all)
    end

    it "sends New post to the new post form" do
      expect(action("new-post")["data-palette-href"]).to eq("/admin/posts/new")
    end

    it "sends New social post to the composer, ready to write" do
      expect(action("new-social-post")["data-palette-href"]).to eq("/admin/social?write=1")
    end

    it "sends Plan tomorrow to the upcoming tasks" do
      expect(action("plan-tomorrow")["data-palette-href"]).to eq("/admin/tasks?filter=upcoming")
    end

    it "posts Import commits to the import route", :aggregate_failures do
      row = action("import-commits")

      expect(row["data-palette-post"]).not_to be_nil
      expect(row["data-palette-href"]).to eq("/admin/commits/import")
    end

    it "posts Sync issues to the sync route", :aggregate_failures do
      row = action("sync-issues")

      expect(row["data-palette-post"]).not_to be_nil
      expect(row["data-palette-href"]).to eq("/admin/tasks/issues/sync")
    end

    it "opens the key help from Keyboard shortcuts, under ?", :aggregate_failures do
      row = action("keyboard-shortcuts")

      expect(row["data-palette-click"]).to eq("[data-key-help-open]")
      expect(row).to have_css(".pal-r-key", text: "?", visible: :all)
    end

    it "flips the theme from Toggle theme" do
      expect(action("toggle-theme")["data-palette-click"]).to eq("[data-theme-choice][aria-pressed='false']")
    end

    it "matches each row on its label and the words for what it does" do
      expect(action("create-task")["data-palette-text"]).to eq("create task, new task, add task")
    end
  end

  describe "the task on screen" do
    before { get "/admin" }

    it "posts Start task to the task on screen", :aggregate_failures do
      row = action("start-task")

      expect(row["data-palette-post"]).not_to be_nil
      expect(row["data-palette-needs"]).to eq("start")
    end

    it "posts Complete task to the task on screen", :aggregate_failures do
      row = action("complete-task")

      expect(row["data-palette-post"]).not_to be_nil
      expect(row["data-palette-needs"]).to eq("complete")
    end

    it "posts Pause task to the task on screen", :aggregate_failures do
      row = action("pause-task")

      expect(row["data-palette-post"]).not_to be_nil
      expect(row["data-palette-needs"]).to eq("pause")
    end

    it "carries the token a post needs" do
      expect(page.find("dialog#command-palette", visible: :all)["data-palette-token"]).to eq(admin_csrf_token)
    end
  end

  describe "the tasks in progress" do
    before { get "/admin" }

    def drawn = rows.map { [it[:id], it.find(".pal-r-label", visible: :all).text(:all), it["data-palette-text"]] }

    def rows
      Capybara.string(Nokogiri::HTML5(last_response.body))
              .all("template[data-palette-from] [data-palette-option]", visible: :all)
    end

    def templates = page.all("template[data-palette-from]", visible: :all)

    it "fetches complete and pause from the route that lists them" do
      expect(templates.map { it["data-palette-from"] })
        .to eq(["/admin/tasks/in-progress", "/admin/tasks/in-progress?act=pause"])
    end

    [
      ["command-palette-complete-task-in-progress", "Complete {title}", "complete {title}, finish task, mark done"],
      ["command-palette-pause-task-in-progress", "Pause {title}", "pause {title}, stop task, stop work"],
    ].each_with_index do |row, at|
      it "draws the #{row[1]} row each one fills in" do
        expect(drawn[at]).to eq(row)
      end
    end

    it "posts each row and shows it only with no task on screen" do
      expect(rows.map { [it["data-palette-post"].nil?, it["data-palette-needs"]] })
        .to eq([[false, "no_task"], [false, "no_task"]])
    end
  end
end

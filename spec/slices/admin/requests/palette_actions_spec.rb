# frozen_string_literal: true

RSpec.describe "Admin palette actions", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def actions = page.all("[aria-labelledby='command-palette-group-actions'] [data-palette-option]", visible: :all)

  def entry(**) = Admin::Operations::ListActions::Entry.new(**)

  before { sign_in_to_admin }

  describe "the list as it ships" do
    before { get "/admin" }

    it "draws one row per entry, in order" do
      expect(actions.map { it[:id] }).to eq(
        %w[create-task create-journal-entry start-task complete-task].map { "command-palette-#{it}" },
      )
    end

    it "sends Create task to the new task dialog, or its page without one", :aggregate_failures do
      row = actions.first

      expect(row["data-palette-dialog"]).to eq("task-create")
      expect(row["data-palette-href"]).to eq("/admin/tasks/new")
    end

    it "sends Create journal entry to the journal, ready to write", :aggregate_failures do
      row = actions[1]

      expect(row["data-palette-dialog"]).to be_nil
      expect(row["data-palette-href"]).to eq("/admin/journal?write=1")
    end

    it "matches each row on its label and the words for what it does" do
      expect(actions.first["data-palette-text"]).to eq("create task, new task, add task")
    end
  end

  describe "the task on screen" do
    before { get "/admin" }

    it "posts Start task to the task on screen", :aggregate_failures do
      row = actions[2]

      expect(row["data-palette-post"]).not_to be_nil
      expect(row["data-palette-needs"]).to eq("start")
    end

    it "posts Complete task to the task on screen", :aggregate_failures do
      row = actions[3]

      expect(row["data-palette-post"]).not_to be_nil
      expect(row["data-palette-needs"]).to eq("complete")
    end

    it "carries the token a post needs" do
      expect(page.find("dialog#command-palette", visible: :all)["data-palette-token"]).to eq(admin_csrf_token)
    end
  end

  describe "the tasks in progress" do
    before { get "/admin" }

    def row
      Capybara.string(Nokogiri::HTML5(last_response.body))
              .find("template[data-palette-from] [data-palette-option]", visible: :all)
    end

    def template = page.find("template[data-palette-from]", visible: :all)

    it "fetches them from the route that lists them" do
      expect(template["data-palette-from"]).to eq("/admin/tasks/in-progress")
    end

    it "draws the row each one fills in", :aggregate_failures do
      expect(row[:id]).to eq("command-palette-complete-task-in-progress")
      expect(row).to have_css(".pal-r-label", text: "Complete {title}", visible: :all)
      expect(row["data-palette-text"]).to eq("complete {title}, finish task, mark done")
    end

    it "posts the row and shows it only with no task on screen", :aggregate_failures do
      expect(row["data-palette-post"]).not_to be_nil
      expect(row["data-palette-needs"]).to eq("no_task")
    end
  end

  describe "adding an entry" do
    before do
      Admin::Slice["i18n"].backend.store_translations(
        :en, ui: { components: { nav: { actions: { review_posts: { label: "Review posts", text: "read drafts" } } } } },
      )
      stub_const(
        "Admin::Operations::ListActions::ALL",
        [*Admin::Operations::ListActions::ALL, entry(name: :review_posts, icon: "fa-eye", route: :admin_posts)],
      )
      get "/admin"
    end

    it "draws its row after the rest", :aggregate_failures do
      row = actions.last

      expect(row[:id]).to eq("command-palette-review-posts")
      expect(row).to have_css(".pal-r-label", text: "Review posts")
      expect(row["data-palette-href"]).to eq("/admin/posts")
      expect(row["data-palette-text"]).to eq("review posts, read drafts")
    end
  end

  describe "an entry that applies only some of the time" do
    before do
      stub_const(
        "Admin::Operations::ListActions::ALL",
        [
          entry(
            name: :create_task, icon: "fa-plus", route: :admin_new_task,
            shows: ->(current_path) { current_path == "/admin/posts" },
          ),
        ],
      )
    end

    it "shows where it applies" do
      get "/admin/posts"

      expect(actions.map { it[:id] }).to eq(%w[command-palette-create-task])
    end

    it "hides where it does not" do
      get "/admin"

      expect(page).to have_no_css("#command-palette-group-actions", visible: :all)
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Admin palette actions", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def actions = page.all("[aria-labelledby='command-palette-group-actions'] [data-palette-option]", visible: :all)

  def entry(**) = Admin::Operations::ListActions::Entry.new(**)

  before { sign_in_to_admin }

  describe "the list as it ships" do
    before { get "/admin" }

    it "draws one row per entry, in order" do
      expect(actions.map { it[:id] }).to eq(%w[command-palette-create-task command-palette-create-journal-entry])
    end

    it "sends Create task to the new task dialog, or its page without one", :aggregate_failures do
      row = actions.first

      expect(row["data-palette-dialog"]).to eq("task-create")
      expect(row["data-palette-href"]).to eq("/admin/tasks/new")
    end

    it "sends Create journal entry to the journal, ready to write", :aggregate_failures do
      row = actions.last

      expect(row["data-palette-dialog"]).to be_nil
      expect(row["data-palette-href"]).to eq("/admin/journal?write=1")
    end

    it "matches each row on its label and the words for what it does" do
      expect(actions.first["data-palette-text"]).to eq("create task, new task, add task")
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

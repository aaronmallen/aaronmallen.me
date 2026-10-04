# frozen_string_literal: true

RSpec.describe "Admin saved views", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { SavedViews::Slice["repos.saved_view_repo"] }

  def links = page.all(".saved-view-link").map(&:text)

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all)

  def views = repo.all

  {
    "tasks" => ["/admin/tasks", { "filter" => "next", "q" => "accountant" }],
    "posts" => ["/admin/posts", { "status" => "draft" }],
    "journal" => ["/admin/journal", { "q" => "commute" }],
    "activity" => ["/admin/activity", { "types" => { "post" => "1", "commit" => "0" }, "q" => "ship" }],
  }.each do |screen, (base, filters)|
    describe "on the #{screen} screen" do
      let(:url) { "#{base}?#{Rack::Utils.build_nested_query(filters)}" }

      before { sign_in_to_admin }

      define_method(:save) do |name, fields = filters|
        form = { screen:, filters: fields, saved_view: { name: }, return_to: url }
        post "/admin/saved-views", _csrf_token: admin_csrf_token, **form
      end

      define_method(:manage) do |view, suffix = "", **fields|
        post "/admin/saved-views/#{view.id}#{suffix}", _csrf_token: admin_csrf_token, return_to: url, **fields
      end

      it "lists the views saved on this screen alone" do
        create(:saved_view, screen:, name: "Mine", filters:)
        create(:saved_view, screen: screen == "tasks" ? "posts" : "tasks", name: "Elsewhere")
        get url

        expect(links).to eq(["Mine"])
      end

      it "opens a view at its filters and marks it current", :aggregate_failures do
        create(:saved_view, screen:, name: "Mine", filters:)
        get url

        expect(page).to have_link("Mine", href: url)
        expect(page).to have_css(".saved-view-link.current[aria-current='page']", text: "Mine")
      end

      it "puts the saved views before the filters" do
        get url

        expect(page).to have_css(".saved-views + *")
      end

      it "holds the screen and its filters in the Save view form", :aggregate_failures do
        get url
        form = page.find("form[action='/admin/saved-views']", visible: :all)

        expect(form).to have_field("screen", type: "hidden", with: screen, visible: :all)
        expect(form).to have_field("return_to", type: "hidden", with: url, visible: :all)
      end

      it "saves the filters the screen reads under the name" do
        save("Weekly", filters.merge("page" => "2", "stray" => "x"))

        expect(views.map { [it.name, it.screen, it.filters] }).to eq([["Weekly", screen, filters]])
      end

      it "returns to the screen with a toast after saving", :aggregate_failures do
        save("Weekly")
        expect(last_response.location).to eq(url)
        follow_redirect!

        expect(toast).to eq("View saved")
      end

      it "refuses a blank name with a toast", :aggregate_failures do
        save(" ")
        follow_redirect!

        expect(views).to be_empty
        expect(toast).to eq("Nothing saved · give the view a name of 100 characters or fewer")
      end

      it "renames a view", :aggregate_failures do
        view = create(:saved_view, screen:, name: "Old")
        manage(view, saved_view: { name: "New" })
        follow_redirect!

        expect(toast).to eq("View renamed")
        expect(links).to eq(["New"])
      end

      it "changes a view to the screen's current filters", :aggregate_failures do
        view = create(:saved_view, screen:, name: "Old")
        manage(view, "/change", filters:)
        follow_redirect!

        expect(toast).to eq("View now holds these filters")
        expect(page).to have_link("Old", href: url)
      end

      it "deletes a view, and it leaves the list", :aggregate_failures do
        view = create(:saved_view, screen:, name: "Old")
        manage(view, "/delete")
        follow_redirect!

        expect(toast).to eq("View deleted")
        expect(links).to be_empty
      end
    end
  end

  describe "a view holding filters the screen no longer knows" do
    before do
      sign_in_to_admin
      create(:saved_view, screen: "tasks", name: "Stale", filters: { "filter" => "gone", "colour" => "red" })
    end

    it "drops the unknown filter from its link" do
      get "/admin/tasks"

      expect(page).to have_link("Stale", href: "/admin/tasks?filter=gone")
    end

    it "opens at the screen's default for a value it no longer takes", :aggregate_failures do
      get "/admin/tasks?filter=gone"

      expect(last_response.status).to eq(200)
      expect(page).to have_css(".subtab[aria-current='page']", text: /\Atoday/i)
    end
  end

  describe "managing a view that is gone or leaving the admin" do
    before { sign_in_to_admin }

    it "answers 404 for a view that is gone" do
      post "/admin/saved-views/999999", _csrf_token: admin_csrf_token, saved_view: { name: "New" }

      expect(last_response.status).to eq(404)
    end

    it "returns home when the return path leaves the admin" do
      view = create(:saved_view, name: "Old")
      post "/admin/saved-views/#{view.id}/delete", _csrf_token: admin_csrf_token, return_to: "https://example.com/"

      expect(last_response.location).to eq("/admin")
    end
  end

  describe "signed out" do
    it "saves nothing" do
      post "/admin/saved-views", screen: "tasks", saved_view: { name: "Weekly" }

      expect(views).to be_empty
    end

    it "deletes nothing" do
      view = create(:saved_view)
      post "/admin/saved-views/#{view.id}/delete"

      expect(repo.by_id(view.id)).not_to be_nil
    end
  end
end

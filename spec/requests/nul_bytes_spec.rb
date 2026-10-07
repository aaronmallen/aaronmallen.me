# frozen_string_literal: true

RSpec.describe "Text holding a NUL byte", type: :request do
  let(:nul) { "dep\0loy" }

  def api(verb, path, body = nil)
    token = API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    public_send(verb, "/api/v1#{path}", body, headers.merge("HTTP_AUTHORIZATION" => "Bearer #{token}"))
    JSON.parse(last_response.body)
  end

  def page = Capybara.string(last_response.body)

  def status = last_response.status

  def views = SavedViews::Slice["repos.saved_view_queries"].all

  before { create(:task, title: "Ship the deploy", note: "deploy") }

  describe "in a search" do
    it "answers the API with 200 and no results" do
      expect([api(:get, "/search", { query: nul }).fetch("results"), status]).to eq([[], 200])
    end

    it "answers the MCP tool with no results" do
      expect(mcp_answer("search", query: nul).fetch("results")).to eq([])
    end

    it "answers the admin search screen with 200 and no results", :aggregate_failures do
      sign_in_to_admin
      get "/admin/search", q: nul

      expect(status).to eq(200)
      expect(page).to have_no_css(".li-title")
    end

    it "answers the admin palette with 200 and no groups" do
      sign_in_to_admin
      get "/admin/search/palette", { q: nul }, { "HTTP_ACCEPT" => "application/json" }

      expect([status, JSON.parse(last_response.body).fetch("groups")]).to eq([200, []])
    end
  end

  describe "in a filter" do
    before { sign_in_to_admin }

    ["dep\0loy", "tag:dep\0loy", "repo:aaronmallen/bl\0og"].each do |query|
      it "answers the admin tasks screen with 200 and no tasks for #{query.inspect}", :aggregate_failures do
        get "/admin/tasks", q: query

        expect(status).to eq(200)
        expect(page).to have_no_text("Ship the deploy")
      end

      it "answers the admin activity screen with 200 for #{query.inspect}" do
        get "/admin/activity", q: query

        expect(status).to eq(200)
      end

      it "answers the admin journal with 200 for #{query.inspect}" do
        get "/admin/journal", q: query

        expect(status).to eq(200)
      end
    end

    it "answers the admin tags screen with 200 and no tags", :aggregate_failures do
      create(:tag, name: "deploy")
      get "/admin/tags", q: nul

      expect(status).to eq(200)
      expect(page).to have_no_text("deploy")
    end

    it "answers a task link search with 200 and no matches", :aggregate_failures do
      get "/admin/tasks/#{create(:task, title: 'Other').id}", link_q: nul

      expect(status).to eq(200)
      expect(page).to have_no_text("Ship the deploy")
    end

    it "answers a record link search with 200 and no matches", :aggregate_failures do
      get "/admin/tasks/#{create(:task, title: 'Other').id}", record_q: nul

      expect(status).to eq(200)
      expect(page).to have_no_text("Ship the deploy")
    end
  end

  describe "in an MCP activity read" do
    let(:today) { Blog::TimeZone.today.iso8601 }

    { text: "dep\0loy", repos: ["bl\0og"], tags: ["dep\0loy"] }.each do |field, value|
      it "reads the window when #{field} holds a NUL" do
        expect(mcp_answer("read_activity", from: today, to: today, field => value)).to include("activity" => Array)
      end
    end
  end

  describe "in a saved view filter" do
    {
      "a value" => ["tasks", { q: "dep\0loy" }],
      "an activity type's value" => ["activity", { types: { post: "1\0" } }],
      "an activity type's name" => ["activity", { types: { "post\0" => "1" } }],
    }.each do |where, (screen, filters)|
      describe "in #{where}" do
        let(:fields) { { name: "Deploys", screen:, filters: } }

        it "refuses the API create with a 422 naming filters", :aggregate_failures do
          expect(api(:post, "/saved_views", JSON.generate(fields)).fetch("errors").keys).to eq(%w[filters])
          expect(status).to eq(422)
        end

        it "refuses the MCP create" do
          expect(mcp_call("create_saved_view", **fields)).to include("isError" => true)
        end

        it "refuses the admin create and saves nothing", :aggregate_failures do
          sign_in_to_admin
          post "/admin/saved-views", _csrf_token: admin_csrf_token, screen:, filters:, saved_view: { name: "Deploys" }

          expect(status).to eq(302)
          expect(views).to be_empty
        end

        it "refuses the admin change and keeps the old filters" do
          view = create(:saved_view, screen:, filters: { q: "ship" })
          sign_in_to_admin
          post "/admin/saved-views/#{view.id}/change", _csrf_token: admin_csrf_token, filters: filters

          expect(views.map(&:filters)).to eq([{ "q" => "ship" }])
        end
      end
    end

    describe "sent with a new name in one PATCH" do
      let(:view) { create(:saved_view, name: "Old", screen: "tasks", filters: { q: "ship" }) }

      before { api(:patch, "/saved_views/#{view.id}", JSON.generate(name: "New", filters: { q: nul })) }

      it "answers 422 naming filters" do
        expect([status, JSON.parse(last_response.body).fetch("errors").keys]).to eq([422, %w[filters]])
      end

      it "leaves the name and the filters alone" do
        expect(views.map { [it.name, it.filters] }).to eq([["Old", { "q" => "ship" }]])
      end
    end
  end
end

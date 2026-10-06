# frozen_string_literal: true

RSpec.describe "API saved views", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(verb, path, body = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    public_send(verb, "/api/v1/saved_views#{path}", body, headers)
    JSON.parse(last_response.body)
  end

  def create_view(fields) = call_api(:post, "", JSON.generate(fields))

  def delete_view(id) = call_api(:delete, "/#{id}")

  def list(**query) = call_api(:get, "", query)

  def status = last_response.status

  def stored(id) = SavedViews::Slice["relations.saved_views"].by_pk(id).one

  def update_view(id, fields) = call_api(:patch, "/#{id}", JSON.generate(fields))

  def views = SavedViews::Slice["relations.saved_views"]

  describe "GET /api/v1/saved_views" do
    it "lists every view by screen and then name" do
      tasks = create(:saved_view, name: "Open", screen: "tasks")
      later = create(:saved_view, name: "Published", screen: "posts")
      drafts = create(:saved_view, name: "Drafts", screen: "posts")

      expect(list.fetch("saved_views").map { it.fetch("id") }).to eq([drafts.id, later.id, tasks.id])
    end

    it "answers each view's ID, name, screen and filters" do
      view = create(:saved_view, name: "Open", screen: "tasks", filters: { q: "deploy" })

      expect(list.fetch("saved_views"))
        .to eq([{ "id" => view.id, "name" => "Open", "screen" => "tasks", "filters" => { "q" => "deploy" } }])
    end

    it "lists only the views on the screen it names" do
      create(:saved_view, screen: "posts")
      journal = create(:saved_view, screen: "journal")

      expect(list(screen: "journal").fetch("saved_views").map { it.fetch("id") }).to eq([journal.id])
    end

    it "leaves out a filter the screen no longer reads" do
      create(:saved_view, screen: "posts", filters: { status: "draft", tag: "ruby" })

      expect(list.dig("saved_views", 0, "filters")).to eq("status" => "draft")
    end

    it "answers no filters for a view whose every filter the screen dropped" do
      create(:saved_view, screen: "journal", filters: { mood: "calm" })

      expect(list.dig("saved_views", 0, "filters")).to eq({})
    end

    Blog::Types::SavedViewScreen.each_value do |screen|
      it "keeps every filter a #{screen} view reads" do
        names = SavedViews::Slice["queries.screen_filters"].call(screen)
        filters = names.to_h { [it, it == "types" ? { "post" => "1" } : "x"] }
        create(:saved_view, screen:, filters: filters.merge("page" => "2"))

        expect(list.dig("saved_views", 0, "filters").keys).to match_array(names)
      end
    end

    it "answers an empty list with 200" do
      expect([list, status]).to eq([{ "saved_views" => [] }, 200])
    end

    it "refuses a screen it does not know with a 422" do
      expect([list(screen: "inbox").fetch("errors").keys, status]).to eq([%w[screen], 422])
    end
  end

  describe "POST /api/v1/saved_views" do
    it "saves the view and answers it with a 201" do
      created = create_view(name: "Open deploys", screen: "tasks", filters: { filter: "next", q: "deploy" })

      view = { "name" => "Open deploys", "screen" => "tasks", "filters" => { "filter" => "next", "q" => "deploy" } }

      expect([created.except("id"), status]).to eq([view, 201])
    end

    it "keeps the activity types as an object" do
      created = create_view(name: "Posts", screen: "activity", filters: { types: { post: "1" } })

      expect(stored(created.fetch("id"))[:filters]).to eq("types" => { "post" => "1" })
    end

    it "keeps only the filters its screen reads" do
      created = create_view(name: "Drafts", screen: "posts", filters: { status: "draft", page: "2" })

      expect(created.fetch("filters")).to eq("status" => "draft")
    end

    it "saves no filters when none come" do
      expect(create_view(name: "Everything", screen: "journal").fetch("filters")).to eq({})
    end

    it "refuses a blank name with a 422 naming the field" do
      blank = "name needs a character that is not a space"
      refusal = { "error" => "invalid", "message" => blank, "errors" => { "name" => [blank] } }

      expect([create_view(name: "  ", screen: "tasks"), status]).to eq([refusal, 422])
    end

    it "refuses a name holding a control character" do
      expect(create_view(name: "bad\u0000name", screen: "tasks").fetch("errors"))
        .to eq("name" => ["name holds a control character"])
    end

    it "refuses a name holding a bell" do
      expect(create_view(name: "bad\u0007name", screen: "tasks").fetch("errors"))
        .to eq("name" => ["name holds a control character"])
    end

    it "refuses a filter holding a control character" do
      expect([create_view(name: "Open", screen: "tasks", filters: { q: "sh\u0007ip" }).fetch("errors").keys, status])
        .to eq([%w[filters], 422])
    end

    it "refuses a long name" do
      expect(create_view(name: "a" * 101, screen: "tasks").fetch("errors"))
        .to eq("name" => ["name runs past 100 characters"])
    end

    it "refuses an object for a filter other than the activity types" do
      expect([create_view(name: "Open", screen: "tasks", filters: { q: { a: "b" } }).fetch("errors").keys, status])
        .to eq([%w[filters], 422])
    end

    it "refuses a filter that is not text" do
      expect([create_view(name: "Open", screen: "tasks", filters: { q: 3 }).fetch("errors").keys, status])
        .to eq([%w[filters], 422])
    end

    it "refuses activity types that are not text" do
      expect([create_view(name: "Posts", screen: "activity", filters: { types: { post: 1 } }).fetch("errors").keys,
              status]).to eq([%w[filters], 422])
    end

    it "refuses a screen it does not know" do
      expect(create_view(name: "Inbox", screen: "inbox").fetch("errors").keys).to eq(%w[screen])
    end

    it "refuses a view with no name" do
      expect(create_view(screen: "tasks").fetch("errors").keys).to eq(%w[name])
    end

    it "refuses a view with no screen" do
      expect(create_view(name: "Open").fetch("errors")).to eq("screen" => ["screen is missing"])
    end

    it "saves nothing it refuses" do
      create_view(name: "", screen: "tasks")

      expect(views.count).to eq(0)
    end
  end

  describe "PATCH /api/v1/saved_views/:id" do
    let(:view) { create(:saved_view, name: "Old", screen: "tasks", filters: { q: "deploy" }) }

    it "renames the view and keeps its filters" do
      expect(update_view(view.id, name: "New"))
        .to eq("id" => view.id, "name" => "New", "screen" => "tasks", "filters" => { "q" => "deploy" })
    end

    it "replaces the filters whole and keeps the name" do
      update_view(view.id, filters: { filter: "next" })

      expect(stored(view.id)).to include(name: "Old", filters: { "filter" => "next" })
    end

    it "changes the name and the filters together" do
      expect(update_view(view.id, name: "New", filters: { pool: "work" }))
        .to include("name" => "New", "filters" => { "pool" => "work" })
    end

    it "clears the filters on an empty object" do
      expect(update_view(view.id, filters: {}).fetch("filters")).to eq({})
    end

    it "answers the view as it is when nothing comes" do
      expect([update_view(view.id, {}).fetch("name"), status]).to eq(["Old", 200])
    end

    it "refuses a blank name with a 422 and keeps the old one" do
      update_view(view.id, name: " ")

      expect([status, stored(view.id)[:name]]).to eq([422, "Old"])
    end

    it "keeps the old name when it refuses the new filters" do
      update_view(view.id, name: "New", filters: { q: { a: "b" } })

      expect([status, stored(view.id)]).to match([422, include(name: "Old", filters: { "q" => "deploy" })])
    end

    it "refuses a field it does not take, such as screen" do
      expect([update_view(view.id, screen: "posts").fetch("errors").keys, status]).to eq([%w[screen], 422])
    end

    it "answers an unknown ID with a 404" do
      expect([update_view(999_999, name: "New"), status])
        .to eq([{ "error" => "not_found", "message" => "no saved view has the ID 999999" }, 404])
    end
  end

  describe "DELETE /api/v1/saved_views/:id" do
    it "removes the view" do
      view = create(:saved_view)

      expect([delete_view(view.id), views.count]).to eq([{ "id" => view.id, "deleted" => true }, 0])
    end

    it "leaves the other views alone" do
      view = create(:saved_view)
      kept = create(:saved_view)
      delete_view(view.id)

      expect(views.pluck(:id)).to eq([kept.id])
    end

    it "answers an unknown ID with a 404" do
      expect([delete_view(999_999), status])
        .to eq([{ "error" => "not_found", "message" => "no saved view has the ID 999999" }, 404])
    end
  end

  describe "the MCP tools" do
    it "list as list_saved_views does" do
      create(:saved_view, screen: "activity", filters: { types: { post: "1" } })

      expect(list(screen: "activity")).to eq(mcp_answer("list_saved_views", screen: "activity"))
    end

    it "create as create_saved_view does" do
      fields = { name: "Open", screen: "tasks", filters: { q: "deploy" } }
      created = create_view(fields)

      expect(mcp_answer("create_saved_view", **fields).except("id")).to eq(created.except("id"))
    end

    it "update as update_saved_view does" do
      view = create(:saved_view, name: "Old")
      updated = update_view(view.id, name: "New", filters: { q: "deploy" })

      expect(mcp_answer("update_saved_view", id: view.id, name: "New", filters: { q: "deploy" })).to eq(updated)
    end

    it "delete as delete_saved_view does" do
      ids = [create(:saved_view).id, create(:saved_view).id]
      deleted = delete_view(ids.first)

      expect(mcp_answer("delete_saved_view", id: ids.last)).to eq(deleted.merge("id" => ids.last))
    end

    it "refuse with the message the endpoint gives" do
      refused = create_view(name: " ", screen: "tasks")

      expect(mcp_text("create_saved_view", name: " ", screen: "tasks")).to eq(refused.fetch("message"))
    end

    it "answer a missing view with the message the endpoint gives" do
      missing = update_view(999_999, name: "New")

      expect(mcp_text("update_saved_view", id: 999_999, name: "New")).to eq(missing.fetch("message"))
    end
  end
end

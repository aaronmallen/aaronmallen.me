# frozen_string_literal: true

RSpec.describe "Admin saved views palette", type: :request do
  def ask = get("/admin/saved-views/palette", {}, { "HTTP_ACCEPT" => "application/json" })

  def row(view, screen, href) = { "id" => view.id, "title" => view.name, "screen" => screen, "href" => href }

  def rows = JSON.parse(last_response.body).fetch("rows")

  describe "signed in" do
    before { sign_in_to_admin }

    describe "with saved views" do
      let!(:drafts) { create(:saved_view, screen: "posts", name: "Drafts", filters: { "status" => "draft" }) }
      let!(:shipped) do
        create(:saved_view, screen: "activity", name: "Shipped",
                            filters: { "q" => "ship", "types" => { "post" => "1" } })
      end
      let!(:everything) { create(:saved_view, screen: "tasks", name: "Everything", filters: {}) }

      let(:listed) do
        [
          row(shipped, "activity", "/admin/activity?types%5Bpost%5D=1&q=ship"),
          row(drafts, "posts", "/admin/posts?status=draft"),
          row(everything, "tasks", "/admin/tasks"),
        ]
      end

      before { ask }

      it "answers with JSON", :aggregate_failures do
        expect(last_response.status).to eq(200)
        expect(last_response.media_type).to eq("application/json")
      end

      it "lists each view by name, in list order, with its screen and the address that opens it" do
        expect(rows).to eq(listed)
      end

      it "keeps the answer out of every cache" do
        expect(last_response.headers["Cache-Control"]).to include("no-store")
      end
    end

    describe "with a filter its screen no longer knows" do
      before do
        create(:saved_view, screen: "posts", name: "Old", filters: { "status" => "draft", "sort" => "oldest" })
        ask
      end

      it "leaves the filter out of the address" do
        expect(rows.first.fetch("href")).to eq("/admin/posts?status=draft")
      end
    end

    describe "with none saved" do
      before { ask }

      it "lists none" do
        expect(rows).to be_empty
      end
    end
  end

  describe "signed out" do
    before { ask }

    it "answers 401 rather than sending me to sign in", :aggregate_failures do
      expect(last_response.status).to eq(401)
      expect(last_response.location).to be_nil
    end
  end
end

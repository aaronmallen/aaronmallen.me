# frozen_string_literal: true

RSpec.describe "API webmention moderation and settings", type: :request do
  def status = last_response.status

  def webmention_queries = Social::Slice["repos.webmention_queries"]

  describe "POST /api/v1/webmentions/:id/moderate" do
    it "files the webmention under the verdict", :aggregate_failures do
      mention = create(:webmention)

      expect([call_api(:post, "/webmentions/#{mention.id}/moderate", { verdict: "spam", reason: "link farm" }), status])
        .to eq([{ "id" => mention.id, "status" => "spam" }, 200])
      expect(webmention_queries.by_id(mention.id).spam_reason).to eq("link farm")
    end

    it "trusts the author of a webmention it approves" do
      mention = create(:webmention)
      call_api(:post, "/webmentions/#{mention.id}/moderate", { verdict: "approved" })

      expect(webmention_queries.trusted_author?(mention.author_url)).to be(true)
    end

    it "trusts the author of a webmention a bulk approve approves" do
      mention = create(:webmention)
      call_api(:post, "/webmentions/bulk/approve", JSON.generate(ids: [mention.id]))

      expect(webmention_queries.trusted_author?(mention.author_url)).to be(true)
    end

    it "refuses a verdict it does not know with a 422" do
      call_api(:post, "/webmentions/#{create(:webmention).id}/moderate", { verdict: "pending" })

      expect(status).to eq(422)
    end

    it "answers an unknown ID with a 404" do
      expect([call_api(:post, "/webmentions/999999/moderate", { verdict: "spam" }).fetch("message"), status])
        .to eq(["no webmention has the ID 999999", 404])
    end
  end

  describe "GET /api/v1/webmention_settings" do
    let(:settings) do
      {
        "accept_bridgy" => true, "auto_approve_known_authors" => true, "auto_approve_likes" => true,
        "auto_approve_reposts" => true, "enable_on_new_posts" => true, "receive" => true, "send_on_publish" => true,
        "single_author_hosts" => [],
      }
    end

    it "reads every setting with a 200" do
      expect([call_api(:get, "/webmention_settings"), status]).to eq([settings, 200])
    end

    it "answers the same JSON as read_webmention_settings" do
      expect(call_api(:get, "/webmention_settings")).to eq(mcp_answer("read_webmention_settings"))
    end
  end

  describe "PATCH /api/v1/webmention_settings" do
    it "changes the settings it was given and keeps the rest" do
      expect(call_api(:patch, "/webmention_settings",
                      { receive: false })).to include("receive" => false, "send_on_publish" => true)
    end

    it "saves the like and repost toggles" do
      expect(call_api(:patch, "/webmention_settings", { auto_approve_likes: false, auto_approve_reposts: false }))
        .to include("auto_approve_likes" => false, "auto_approve_reposts" => false)
    end

    it "saves the hosts it was given, cleaned up and in order" do
      hosts = ["grace.example", "https://Ada.Example/"]
      found = call_api(:patch, "/webmention_settings", { single_author_hosts: hosts })

      expect(found.fetch("single_author_hosts")).to eq(%w[ada.example grace.example])
    end

    it "refuses a change that changes nothing with a 422" do
      expect([call_api(:patch, "/webmention_settings", { receive: true }).fetch("message"), status])
        .to eq(["nothing saved, since no setting changed", 422])
    end
  end

  describe "trusted authors" do
    let(:ada) { "https://ada.example/" }

    def trust(url) = Social::Slice["repos.webmention_mutations"].trust(url, approve_pending: false)

    before { trust(ada) }

    it "lists the trusted authors" do
      expect(call_api(:get, "/trusted_authors").fetch("trusted_authors").map { it.fetch("author_url") }).to eq([ada])
    end

    it "lists them as list_trusted_authors does" do
      expect(call_api(:get, "/trusted_authors")).to eq(trusted(mcp_answer("list_trusted_authors")))
    end

    it "removes an author", :aggregate_failures do
      expect([call_api(:post, "/trusted_authors/remove", { author_url: ada }), status])
        .to eq([{ "author_url" => ada, "removed" => true }, 200])
      expect(webmention_queries.trusted_author?(ada)).to be(false)
    end

    it "removes an author given under another case" do
      call_api(:post, "/trusted_authors/remove", { author_url: "https://ADA.example" })

      expect(webmention_queries.trusted_author?(ada)).to be(false)
    end

    it "answers an author not on the list with a 404" do
      expect([call_api(:post, "/trusted_authors/remove", { author_url: "https://grace.example/" }).fetch("message"),
              status]).to eq(["no trusted author has the URL https://grace.example/", 404])
    end

    it "needs the delete scope to remove an author" do
      call_api(:post, "/trusted_authors/remove", { author_url: ada }, token: api_token(%w[read write publish]))

      expect(status).to eq(403)
    end
  end
end

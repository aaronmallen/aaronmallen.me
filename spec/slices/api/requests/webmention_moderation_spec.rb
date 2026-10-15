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
    it "reads every setting with a 200" do
      settings = {
        "accept_bridgy" => true, "auto_approve_known_authors" => true, "enable_on_new_posts" => true,
        "receive" => true, "send_on_publish" => true, "single_author_hosts" => [],
      }

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
end

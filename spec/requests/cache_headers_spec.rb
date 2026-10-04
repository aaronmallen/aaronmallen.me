# frozen_string_literal: true

RSpec.describe "Cache headers", type: :request do
  def cache_control = last_response.headers["Cache-Control"]

  def page = Capybara.string(last_response.body)

  def shared = "public, max-age=0, s-maxage=300"

  def shared_paths(slug)
    ["/", "/about", "/privacy", "/projects", "/writing", "/writing/#{slug}", "/writing/tags/ruby"]
  end

  def vary = last_response.headers["Vary"]

  describe "a public page the operator asked for" do
    before do
      sign_in_to_admin
      get "/"
    end

    it "carries the admin token" do
      expect(last_response.body).to include(admin_csrf_token)
    end

    it "tells every cache not to store it" do
      expect(cache_control).to eq("private, no-store")
    end

    it "keys on the cookie" do
      expect(vary).to eq("Cookie")
    end
  end

  describe "a feed the operator asked for" do
    before do
      create(:post, :published)
      sign_in_to_admin
      get "/writing.atom"
    end

    it "tells every cache not to store it" do
      expect(cache_control).to eq("private, no-store")
    end

    it "tells every cache not to store the 304 either", :aggregate_failures do
      get "/writing.atom", {}, "HTTP_IF_NONE_MATCH" => last_response.headers["ETag"]

      expect(last_response.status).to eq(304)
      expect(cache_control).to eq("private, no-store")
    end
  end

  describe "a feed a visitor asked for" do
    before do
      create(:post, :published, tags: ["ruby"])
      get "/writing.atom"
    end

    it "tells a shared cache not to keep it" do
      expect(cache_control).to eq("private, no-cache")
    end

    it "tells a shared cache not to keep the 304 either", :aggregate_failures do
      get "/writing.atom", {}, "HTTP_IF_NONE_MATCH" => last_response.headers["ETag"]

      expect(last_response.status).to eq(304)
      expect(cache_control).to eq("private, no-cache")
    end

    it "tells a shared cache not to keep a tag feed" do
      get "/writing/tags/ruby.atom"

      expect(cache_control).to eq("private, no-cache")
    end
  end

  describe "a public page a visitor asked for" do
    before { get "/" }

    it "carries no admin token" do
      expect(page).to have_no_css("form[action='/admin/sign-out']", visible: :all)
    end

    it "lets a shared cache keep it for five minutes" do
      expect(cache_control).to eq(shared)
    end

    it "keys on the cookie" do
      expect(vary).to eq("Cookie")
    end
  end

  describe "a public page a forged cookie asked for" do
    before do
      set_cookie "#{Blog::SessionCookie::KEY}=forged"
      get "/"
    end

    it "carries no admin token" do
      expect(page).to have_no_css("form[action='/admin/sign-out']", visible: :all)
    end

    it "keeps it from a shared cache" do
      expect(cache_control).to be_nil
    end
  end

  describe "a public page the operator signed out of" do
    before do
      sign_in_to_admin
      post "/admin/sign-out", _csrf_token: admin_csrf_token
      get "/"
    end

    it "lets a shared cache keep it" do
      expect(cache_control).to eq(shared)
    end
  end

  describe "a public page a visitor with a saved theme asked for" do
    before do
      set_cookie "#{Blog::UI::Layouts::Application::THEME_COOKIE}=dark"
      get "/"
    end

    it "keeps it from a shared cache" do
      expect(cache_control).to be_nil
    end
  end

  describe "the public pages a visitor asked for" do
    let(:article) { create(:post, :published, tags: ["ruby"]) }

    it "lets a shared cache keep each one", :aggregate_failures do
      shared_paths(article.slug).each do |path|
        get path

        expect([path, last_response.status, cache_control]).to eq([path, 200, shared])
      end
    end

    it "shows an edit to a post on the next request", :aggregate_failures do
      get "/writing/#{article.slug}"
      Posts::Slice["repos.post_repo"].update(article.id, title: "Edited")
      get "/writing/#{article.slug}"

      expect(page).to have_css("h1", text: "Edited")
      expect(cache_control).to eq(shared)
    end
  end

  describe "the public pages the operator asked for" do
    let(:article) { create(:post, :published, tags: ["ruby"]) }

    before { sign_in_to_admin }

    it "tells every cache not to store any of them", :aggregate_failures do
      [*shared_paths(article.slug), "/contact"].each do |path|
        get path

        expect([path, cache_control]).to eq([path, "private, no-store"])
      end
    end
  end

  describe "the contact page a visitor asked for" do
    before { get "/contact" }

    it "tells every cache not to store it" do
      expect(cache_control).to eq("private, no-store")
    end
  end

  describe "a public page that is not there" do
    it "keeps a missing post from a shared cache", :aggregate_failures do
      get "/writing/no-such-post"

      expect(last_response.status).to eq(404)
      expect(cache_control).to be_nil
    end

    it "keeps a missing tag from a shared cache", :aggregate_failures do
      get "/writing/tags/nothing"

      expect(last_response.status).to eq(404)
      expect(cache_control).to be_nil
    end
  end

  describe "a tag page at another spelling" do
    before do
      create(:post, :published, tags: ["ruby"])
      get "/writing/tags/Ruby"
    end

    it "keeps the redirect from a shared cache", :aggregate_failures do
      expect(last_response.status).to eq(301)
      expect(cache_control).to be_nil
    end
  end

  describe "an admin page" do
    before do
      sign_in_to_admin
      get "/admin"
    end

    it "tells every cache not to store it" do
      expect(cache_control).to eq("private, no-store")
    end
  end

  describe "the admin sign-in page" do
    before do
      connect_github(client_id: "client-id", client_secret: "client-secret")
      get "/admin/sign-in"
    end

    it "tells every cache not to store it" do
      expect(cache_control).to eq("private, no-store")
    end
  end

  describe "an admin form without a token" do
    before do
      sign_in_to_admin
      post "/admin/projects", project: { name: "sneaky" }
    end

    it "tells every cache not to store the refusal" do
      expect(cache_control).to eq("private, no-store")
    end
  end

  describe "the MCP approval page" do
    let(:client) { Spec::DB::Factories[:mcp].create(:oauth_client) }
    let(:verifier) { MCP::OAuth::Secret.generate }

    before do
      sign_in_to_admin
      get "/oauth/authorize", {
        client_id: client.client_id,
        code_challenge: MCP::OAuth::PKCE.challenge(verifier),
        code_challenge_method: "S256",
        redirect_uri: client.redirect_uris.first,
        response_type: "code",
        scope: "read",
      }
    end

    it "carries the approval token" do
      expect(page).to have_css("form[action='/oauth/authorize'] input[name='_csrf_token']", visible: :all)
    end

    it "tells every cache not to store it" do
      expect(cache_control).to eq("private, no-store")
    end
  end
end

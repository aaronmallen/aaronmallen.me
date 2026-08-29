# frozen_string_literal: true

RSpec.describe "Cache headers", type: :request do
  def cache_control = last_response.headers["Cache-Control"]

  def page = Capybara.string(last_response.body)

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

  describe "a public page a visitor asked for" do
    before { get "/" }

    it "carries no admin token" do
      expect(page).to have_no_css("form[action='/admin/sign-out']", visible: :all)
    end

    it "leaves a cache free to store it" do
      expect(cache_control).to be_nil
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

    it "leaves a cache free to store it" do
      expect(cache_control).to be_nil
    end
  end

  describe "a public page the operator signed out of" do
    before do
      sign_in_to_admin
      post "/admin/sign-out", _csrf_token: admin_csrf_token
      get "/"
    end

    it "leaves a cache free to store it" do
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

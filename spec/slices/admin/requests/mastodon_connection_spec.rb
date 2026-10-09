# frozen_string_literal: true

RSpec.describe "Admin Mastodon connection", type: :request do
  let(:apps_url) { "https://ruby.social/api/v1/apps" }
  let(:revoke_url) { "https://ruby.social/oauth/revoke" }
  let(:scope) { "write:statuses read:accounts read:search read:statuses" }

  before do
    sign_in_to_admin
    stub_request(:post, apps_url).to_return(**json_response(client_id: "app-id", client_secret: "app-secret"))
    stub_request(:post, "https://ruby.social/oauth/token")
      .to_return(**json_response(access_token: "masto-token", scope:, token_type: "Bearer"))
    stub_request(:get, "https://ruby.social/api/v1/accounts/verify_credentials")
      .with(headers: { "Authorization" => "Bearer masto-token" })
      .to_return(**json_response(id: "109", username: "aaronmallen", acct: "aaronmallen"))
  end

  def authorize_query = Rack::Utils.parse_query(URI(last_response.location).query)

  def callback(**) = get("/admin/auth/mastodon/callback", **)

  def connections = Services::Slice["repos.connection_queries"].for(:mastodon)

  def page = Capybara.string(last_response.body)

  def start_connect(server = "ruby.social")
    post "/admin/services/mastodon/connect", server:, _csrf_token: admin_csrf_token
    authorize_query["state"]
  end

  it "asks for my server in the picker" do
    get "/admin/services"

    expect(page).to have_css("form[action='/admin/services/mastodon/connect'] input[name='server']", visible: :all)
  end

  describe "starting" do
    before { start_connect("https://Ruby.Social/@aaronmallen") }

    it "sends me to my server asking for the scopes the site needs", :aggregate_failures do
      expect(last_response.location).to start_with("https://ruby.social/oauth/authorize?")
      expect(authorize_query).to include("client_id" => "app-id", "scope" => scope, "code_challenge_method" => "S256")
      expect(authorize_query.fetch("redirect_uri")).to end_with("/admin/auth/mastodon/callback")
    end

    it "registers the site on the server with the same scopes and callback" do
      registered = a_request(:post, apps_url).with(
        body: hash_including("scopes" => scope, "redirect_uris" => %r{/admin/auth/mastodon/callback\z}),
      )

      expect(registered).to have_been_made.once
    end

    it "reuses the registered app on the next connect", :aggregate_failures do
      start_connect

      expect(a_request(:post, apps_url)).to have_been_made.once
      expect(authorize_query).to include("client_id" => "app-id")
    end
  end

  describe "a server it cannot use" do
    it "refuses a bad server name before leaving the site", :aggregate_failures do
      start_connect("not a server")
      follow_redirect!

      expect(a_request(:post, apps_url)).not_to have_been_made
      expect(page).to have_css("[data-toast]", text: "That isn't a server name")
    end

    it "refuses a server that does not answer as Mastodon", :aggregate_failures do
      stub_request(:post, apps_url).to_return(status: 404)
      start_connect
      follow_redirect!

      expect(last_request.path).to eq("/admin/services")
      expect(page).to have_css("[data-toast]", text: "didn't answer as Mastodon")
    end
  end

  describe "when the server grants access" do
    before do
      callback(code: "code", state: start_connect)
      follow_redirect!
    end

    it "saves the account on its server with its scopes and token", :aggregate_failures do
      connection, = connections

      expect([connection.host, connection.account_id, connection.label, connection.scopes])
        .to eq(["ruby.social", "109", "@aaronmallen@ruby.social", scope.split])
      expect(connection.credentials).to include(access_token: "masto-token", client_id: "app-id")
    end

    it "sends the PKCE verifier with the code" do
      verified = a_request(:post, "https://ruby.social/oauth/token").with(body: /code_verifier=[\w-]{64}/)

      expect(verified).to have_been_made
    end

    it "says who it connected" do
      expect(page).to have_css("[data-toast]", text: "Mastodon connected as @aaronmallen@ruby.social")
    end

    it "posts with the new token with no restart" do
      token = { "Authorization" => "Bearer masto-token" }
      statuses = stub_request(:post, SocialNetworks::MASTODON_STATUSES)
      posted = statuses.with(headers: token).to_return(**json_response(id: "1"))
      Social::Slice["networks.all"].fetch("mastodon").post("Hello", idempotency_key: "key")

      expect(posted).to have_been_made
    end
  end

  describe "refusals" do
    it "saves nothing when I decline on the server", :aggregate_failures do
      callback(error: "access_denied", state: start_connect)
      follow_redirect!

      expect(connections).to be_empty
      expect(page).to have_css("[data-toast]", text: "Mastodon didn't grant access")
    end

    it "refuses a state it never sent", :aggregate_failures do
      start_connect
      callback(code: "code", state: "forged")
      follow_redirect!

      expect(connections).to be_empty
      expect(page).to have_css("[data-toast]", text: "didn't start here")
    end

    it "saves nothing when the server fails the exchange", :aggregate_failures do
      stub_request(:post, "https://ruby.social/oauth/token").to_return(status: 500)
      callback(code: "code", state: start_connect)
      follow_redirect!

      expect(connections).to be_empty
      expect(page).to have_css("[data-toast]", text: "didn't answer as Mastodon")
    end
  end

  describe "disconnecting" do
    let(:connection) do
      callback(code: "code", state: start_connect)
      connections.first
    end

    let(:revoke) do
      a_request(:post, revoke_url)
        .with(body: { "client_id" => "app-id", "client_secret" => "app-secret", "token" => "masto-token" })
    end

    def disconnect = post("/admin/services/#{connection.id}/disconnect", _csrf_token: admin_csrf_token)

    it "revokes the token on the server and deletes the row", :aggregate_failures do
      stub_request(:post, revoke_url).to_return(status: 200, body: "{}")
      disconnect

      expect(revoke).to have_been_made
      expect(connections).to be_empty
    end

    it "deletes the row when the server will not revoke" do
      stub_request(:post, revoke_url).to_return(status: 403)
      disconnect

      expect(connections).to be_empty
    end
  end
end

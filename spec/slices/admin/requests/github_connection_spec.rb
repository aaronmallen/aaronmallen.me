# frozen_string_literal: true

RSpec.describe "Admin GitHub connection", type: :request do
  let(:revoke_url) { "https://api.github.com/applications/client-id/token" }
  let(:revoke) do
    a_request(:delete, revoke_url).with(basic_auth: %w[client-id client-secret], body: { access_token: "ghp_token" })
  end
  let(:token_body) { { access_token: "gho_data", scope: "repo,read:org", token_type: "bearer" } }

  before do
    sign_in_to_admin
    stub_request(:post, "https://github.com/login/oauth/access_token")
      .to_return(headers: { "Content-Type" => "application/json" }, body: token_body.to_json)
    stub_request(:get, "https://api.github.com/user")
      .with(headers: { "Authorization" => "Bearer gho_data" })
      .to_return(headers: { "Content-Type" => "application/json" }, body: { id: 931_094, login: "aaronmallen" }.to_json)
  end

  def authorize_query = Rack::Utils.parse_query(URI(last_response.location).query)

  def callback(**) = get("/admin/auth/github/callback", **)

  def connections = Services::Slice["repos.connection_queries"].for(:github)

  def page = Capybara.string(last_response.body)

  def start_connect
    post "/admin/services/github/connect", _csrf_token: admin_csrf_token
    authorize_query.fetch("state")
  end

  describe "starting" do
    before { start_connect }

    it "sends me to GitHub asking for the scopes the reads need", :aggregate_failures do
      expect(last_response.location).to start_with("https://github.com/login/oauth/authorize?")
      expect(authorize_query).to include("client_id" => "client-id", "scope" => "repo read:org")
    end

    it "sends a PKCE challenge and comes back to the sign-in callback", :aggregate_failures do
      expect(authorize_query).to include("code_challenge_method" => "S256")
      expect(authorize_query.fetch("code_challenge")).to match(/\A[\w-]{43}\z/)
      expect(authorize_query.fetch("redirect_uri")).to end_with("/admin/auth/github/callback")
    end
  end

  describe "when GitHub grants access" do
    before do
      callback(code: "code", state: start_connect)
      follow_redirect!
    end

    it "saves the account with its scopes and token", :aggregate_failures do
      connection, = connections

      expect([connection.account_id, connection.label,
              connection.scopes]).to eq(["931094", "@aaronmallen", %w[repo read:org]])
      expect(connection.credentials).to eq(access_token: "gho_data")
    end

    it "sends the PKCE verifier with the code" do
      verified = a_request(:post, "https://github.com/login/oauth/access_token").with(body: /code_verifier=[\w-]{64}/)

      expect(verified).to have_been_made
    end

    it "sends the sign-in callback with the code" do
      callback = /redirect_uri=[^&]*%2Fadmin%2Fauth%2Fgithub%2Fcallback(&|\z)/
      sent = a_request(:post, "https://github.com/login/oauth/access_token").with(body: callback)

      expect(sent).to have_been_made
    end

    it "opens the connection with its account and scopes granted", :aggregate_failures do
      expect(last_request.path).to eq("/admin/services")
      expect(page).to have_css("[data-toast]", text: "GitHub connected as @aaronmallen")
      expect(page).to have_css(".settings-side .svc-account", text: "@aaronmallen")
      expect(page.find(".svc-line", text: "Read repositories and issues")).to have_css(".pill", text: "granted")
    end

    it "hides GitHub from the picker" do
      expect(page).to have_no_css("#connect-service .svc-pick", text: "GitHub", visible: :all)
    end

    it "lets the record client read it with no restart" do
      expect(Record::Slice["github.client"]).to be_configured
    end
  end

  it "offers GitHub in the picker while it is not connected" do
    get "/admin/services"

    expect(page).to have_css("#connect-service .svc-pick", text: "GitHub", visible: :all)
  end

  describe "refusals" do
    it "saves nothing when I decline on GitHub", :aggregate_failures do
      callback(error: "access_denied", state: start_connect)
      follow_redirect!

      expect(connections).to be_empty
      expect(page).to have_css("[data-toast]", text: "GitHub didn't grant access")
    end

    it "refuses a state it never sent", :aggregate_failures do
      start_connect
      callback(code: "code", state: "forged")

      expect(connections).to be_empty
      expect(last_response.status).to eq(401)
    end

    it "refuses a state that has expired", :aggregate_failures do
      state = start_connect
      allow(Time).to receive(:now).and_return(Time.now + (11 * 60))
      callback(code: "code", state:)

      expect(connections).to be_empty
      expect(last_response.location).to end_with("/admin/services")
    end

    it "refuses a connect state once I have signed out", :aggregate_failures do
      state = start_connect
      post "/admin/sign-out", _csrf_token: admin_csrf_token
      callback(code: "code", state:)

      expect(connections).to be_empty
      expect(last_response.status).to eq(401)
    end

    it "refuses a state used once already", :aggregate_failures do
      state = start_connect
      callback(code: "code", state:)
      Services::Slice["relations.service_connections"].delete
      callback(code: "code", state:)

      expect(connections).to be_empty
    end

    it "refuses a second GitHub account", :aggregate_failures do
      connect_github_account(account_id: "1", label: "@someone")
      callback(code: "code", state: start_connect)
      follow_redirect!

      expect(connections.map(&:label)).to eq(["@someone"])
      expect(page).to have_css("[data-toast]", text: "GitHub takes one account")
    end

    it "saves nothing when GitHub fails the exchange" do
      stub_request(:post, "https://github.com/login/oauth/access_token").to_return(status: 500)
      callback(code: "code", state: start_connect)

      expect(connections).to be_empty
    end
  end

  describe "disconnecting" do
    let(:connection) { connect_github_account }

    def disconnect = post("/admin/services/#{connection.id}/disconnect", _csrf_token: admin_csrf_token)

    it "revokes the token on GitHub and deletes the row", :aggregate_failures do
      stub_request(:delete, revoke_url).to_return(status: 204)
      disconnect

      expect(revoke).to have_been_made
      expect(connections).to be_empty
    end

    it "deletes the row when GitHub will not revoke" do
      stub_request(:delete, revoke_url).to_return(status: 422)
      disconnect

      expect(connections).to be_empty
    end

    it "answers 404 for a connection it does not hold" do
      post "/admin/services/0/disconnect", _csrf_token: admin_csrf_token

      expect(last_response.status).to eq(404)
    end
  end
end

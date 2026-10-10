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

    it "says it signed in with OAuth" do
      expect(page.find(".svc-line", text: "Signed in with")).to have_css(".pill", text: "OAuth")
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

  it "asks for no server in the picker" do
    get "/admin/services"

    expect(page).to have_no_css("form[action='/admin/services/github/connect'] input[name='server']", visible: :all)
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

  describe "connecting with a personal access token" do
    let(:user_url) { "https://api.github.com/user" }

    def connect_token(token)
      post("/admin/services/github", connection: { access_token: token }, _csrf_token: admin_csrf_token)
    end

    def stub_user(token, status: 200, body: { id: 931_094, login: "aaronmallen" }, scopes: "repo, read:org")
      headers = { "Content-Type" => "application/json", "X-OAuth-Scopes" => scopes }
      stub_request(:get, user_url).with(headers: { "Authorization" => "Bearer #{token}" })
                                  .to_return(status:, headers:, body: body.to_json)
    end

    it "offers a token field beside Sign in with GitHub", :aggregate_failures do
      get "/admin/services"
      dialog = page.find_by_id("connect-service-github", visible: :all)
      token = "form[action='/admin/services/github'] input[type='password'][name='connection[access_token]']"

      expect(dialog).to have_css("form[action='/admin/services/github/connect']", visible: :all)
      expect(dialog).to have_css(token, visible: :all)
    end

    describe "with a token GitHub accepts" do
      before do
        stub_user("ghp_new")
        connect_token(" ghp_new ")
        follow_redirect!
      end

      it "saves the account with its scopes and the token sealed", :aggregate_failures do
        connection, = connections

        expect([connection.account_id, connection.label,
                connection.scopes]).to eq(["931094", "@aaronmallen", %w[repo read:org]])
        expect(connection.credentials).to eq(access_token: "ghp_new", auth: "credentials")
      end

      it "opens the connection and says it signed in with a token", :aggregate_failures do
        expect(page).to have_css("[data-toast]", text: "GitHub connected as @aaronmallen")
        expect(page.find(".svc-line", text: "Signed in with")).to have_css(".pill", text: "personal access token")
      end

      it "lets the record client call GitHub with the token with no restart" do
        stub_request(:get, "https://api.github.com/repos/aaronmallen/blog")
          .with(headers: { "Authorization" => "Bearer ghp_new" })
          .to_return(headers: { "Content-Type" => "application/json" }, body: { stargazers_count: 3 }.to_json)

        expect(Record::Slice["github.client"].stars("aaronmallen/blog")).to eq(3)
      end
    end

    it "lists no scopes for a fine-grained token" do
      stub_user("github_pat_new", scopes: "")
      connect_token("github_pat_new")
      follow_redirect!

      expect(page).to have_no_css(".svc-line", text: "Read repositories and issues")
    end

    it "saves nothing for a token GitHub refuses and shows why", :aggregate_failures do
      stub_user("ghp_bad", status: 401, body: { message: "Bad credentials" })
      connect_token("ghp_bad")

      expect(last_response.status).to eq(422)
      expect(page).to have_css(".settings-side .field-error", text: "Bad credentials")
      expect(connections).to be_empty
    end

    it "saves nothing for a blank token", :aggregate_failures do
      connect_token("  ")

      expect(page).to have_css(".field-error", text: "Paste a token first")
      expect(a_request(:get, user_url)).not_to have_been_made
    end

    it "refuses a token while GitHub is already connected", :aggregate_failures do
      connect_github_account(account_id: "1", label: "@someone")
      stub_user("ghp_new")
      connect_token("ghp_new")

      expect(page).to have_css(".field-error", text: "The site holds one account")
      expect(connections.map(&:label)).to eq(["@someone"])
    end

    describe "once connected" do
      let(:connection) do
        Services::Slice["repos.connection_mutations"].add(
          provider: "github", account_id: "931094", label: "@aaronmallen",
          credentials: { access_token: "ghp_new", auth: "credentials" }, scopes: [],
        )
      end

      def toast = page.find("[data-toast]").text

      it "reports that GitHub answers a test" do
        stub_user("ghp_new")
        post "/admin/services/#{connection.id}/test", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(toast).to include("GitHub answered")
      end

      it "reports that GitHub refuses a test" do
        stub_user("ghp_new", status: 401, body: { message: "Bad credentials" })
        post "/admin/services/#{connection.id}/test", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(toast).to include("GitHub isn't answering", "Bad credentials")
      end

      it "deletes the row and asks me to revoke the token on GitHub", :aggregate_failures do
        post "/admin/services/#{connection.id}/disconnect", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(connections).to be_empty
        expect(a_request(:delete, revoke_url)).not_to have_been_made
        expect(toast).to include("revoke its token on GitHub")
      end
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

# frozen_string_literal: true

RSpec.describe "Admin Google Health connection", type: :request do
  let(:steps_url) { "https://health.googleapis.com/v4/users/me/dataTypes/steps/dataPoints?page_size=1" }
  let(:scopes) do
    %w[sleep activity_and_fitness health_metrics_and_measurements]
      .map { "https://www.googleapis.com/auth/googlehealth.#{it}.readonly" }
  end
  let(:token_url) { "https://oauth2.googleapis.com/token" }

  before { sign_in_to_admin }

  def authorize_query = Rack::Utils.parse_query(URI(last_response.location).query)

  def callback(**) = get("/admin/auth/google_health/callback", **)

  def client = Health::Slice["google.client"]

  def connect_account(expires_at: Time.now.to_i + 3600, revoked_at: nil)
    Services::Slice["repos.connection_mutations"].add(
      provider: "google_health", account_id: "me", label: "Google account", revoked_at:,
      credentials: { access_token: "ya29.old", expires_at:, refresh_token: "1//refresh" },
    )
  end

  def connection = Services::Slice["repos.connection_queries"].for(:google_health).first

  def page = Capybara.string(last_response.body)

  def pickable = page.all("#connect-service .svc-pick .svc-line-name", visible: :all).map(&:text)

  def set_up_google_health(credentials = { client_id: "google-id", client_secret: "google-secret" })
    allow(Hanami.app.settings).to receive(:google_health).and_return(credentials)
    Health::Slice.start(:google)
    client = Health::Providers::GoogleProvider.client(
      Hanami.app.settings, Health::Slice["services.repos.connection_queries"],
      Health::Slice["services.operations.change_connection"],
    )
    %w[google.client health.google.client].each { replace_component(it, client) }
  end

  def start_connect
    post "/admin/services/google_health/connect", _csrf_token: admin_csrf_token
    authorize_query.fetch("state")
  end

  def stub_steps(token, status: 200)
    stub_request(:get, steps_url)
      .with(headers: { "Authorization" => "Bearer #{token}" })
      .to_return(status:, headers: { "Content-Type" => "application/json" }, body: "{}")
  end

  def stub_token(body, status: 200)
    stub_request(:post, token_url)
      .to_return(status:, headers: { "Content-Type" => "application/json" }, body: body.to_json)
  end

  def toast = page.find("[data-toast]").text

  describe "without client credentials in settings" do
    before { set_up_google_health({}) }

    it "lists Google Health as not set up and leaves it out of the picker", :aggregate_failures do
      get "/admin/services"

      expect(page.find(".svc-group", text: "Health")).to have_css(".li", text: /Google Health.*not set up/)
      expect(pickable).not_to include("Google Health")
    end

    it "names the missing settings on its detail" do
      get "/admin/services", selected: "google_health"

      expect(page.find(".svc-line", text: "GOOGLE_HEALTH_CLIENT_ID")).to have_css(".pill", text: "missing")
    end

    it "refuses to start a connect", :aggregate_failures do
      post "/admin/services/google_health/connect", _csrf_token: admin_csrf_token
      follow_redirect!

      expect(toast).to include("Google Health sign-in isn't set up")
      expect(connection).to be_nil
    end

    it "reads nothing from Google" do
      expect(client.get("users/me/dataTypes/steps/dataPoints")).to be_nil
    end
  end

  describe "with client credentials in settings" do
    before { set_up_google_health }

    it "offers Google Health in the picker" do
      get "/admin/services"

      expect(pickable).to include("Google Health")
    end

    describe "starting" do
      before { start_connect }

      it "sends me to Google asking offline for the three read-only scopes", :aggregate_failures do
        expect(last_response.location).to start_with("https://accounts.google.com/o/oauth2/v2/auth?")
        expect(authorize_query).to include(
          "client_id" => "google-id", "access_type" => "offline", "prompt" => "consent", "scope" => scopes.join(" "),
        )
      end

      it "sends a PKCE challenge and comes back to the Google Health callback", :aggregate_failures do
        expect(authorize_query).to include("code_challenge_method" => "S256")
        expect(authorize_query.fetch("redirect_uri")).to end_with("/admin/auth/google_health/callback")
      end

      it "leaves out include_granted_scopes" do
        expect(authorize_query).not_to have_key("include_granted_scopes")
      end
    end

    describe "when Google grants access" do
      before do
        grant = { access_token: "ya29.new", expires_in: 3599, refresh_token: "1//refresh", token_type: "Bearer" }
        stub_token({ **grant, scope: scopes.first })
        callback(code: "code", state: start_connect)
        follow_redirect!
      end

      it "keeps the refresh token sealed with the access token", :aggregate_failures do
        expect(connection.credentials).to include(access_token: "ya29.new", refresh_token: "1//refresh")
        expect(connection.scopes).to eq(["https://www.googleapis.com/auth/googlehealth.sleep.readonly"])
      end

      it "opens the connection as connected", :aggregate_failures do
        expect(toast).to include("Google Health connected")
        expect(page.find(".settings-side")).to have_css(".pill", text: "connected")
        expect(page.find(".svc-line", text: "Read sleep")).to have_css(".pill", text: "granted")
      end

      it "hides Google Health from the picker" do
        expect(pickable).not_to include("Google Health")
      end
    end

    it "saves nothing when I decline on Google", :aggregate_failures do
      callback(error: "access_denied", state: start_connect)
      follow_redirect!

      expect(connection).to be_nil
      expect(toast).to include("Google Health didn't grant access")
    end

    it "saves nothing when Google fails the exchange" do
      stub_token({ error: "invalid_grant" }, status: 400)
      callback(code: "code", state: start_connect)

      expect(connection).to be_nil
    end

    it "refuses a state it never sent" do
      start_connect
      callback(code: "code", state: "forged")

      expect(connection).to be_nil
    end

    describe "reading with an expired access token" do
      before do
        connect_account(expires_at: Time.now.to_i - 60)
        stub_token({ access_token: "ya29.fresh", expires_in: 3599, token_type: "Bearer" })
        stub_steps("ya29.fresh")
      end

      it "refreshes it and reads with the new one" do
        client.get("users/me/dataTypes/steps/dataPoints", page_size: 1)

        refreshed = hash_including("grant_type" => "refresh_token", "refresh_token" => "1//refresh")

        expect(a_request(:post, token_url).with(body: refreshed)).to have_been_made
      end

      it "writes the new access token back and keeps the refresh token" do
        client.get("users/me/dataTypes/steps/dataPoints", page_size: 1)

        expect(connection.credentials).to include(access_token: "ya29.fresh", refresh_token: "1//refresh")
      end
    end

    it "refreshes and tries again when Google turns down a token that has not expired" do
      connect_account
      stub_steps("ya29.old", status: 401)
      stub_token({ access_token: "ya29.fresh", expires_in: 3599, token_type: "Bearer" })
      stub_steps("ya29.fresh")

      expect(client.get("users/me/dataTypes/steps/dataPoints", page_size: 1)).to eq({})
    end

    describe "when Google has revoked the refresh token" do
      before do
        connect_account(expires_at: Time.now.to_i - 60)
        stub_token({ error: "invalid_grant" }, status: 400)
      end

      def read = client.get("users/me/dataTypes/steps/dataPoints")

      it "marks the service as needing a reconnect", :aggregate_failures do
        expect { read }.to raise_error(Health::Error, "Google Health needs a reconnect")
        expect(connection.revoked_at).not_to be_nil
      end

      it "shows it needs a reconnect and offers to reconnect", :aggregate_failures do
        expect { read }.to raise_error(Health::Error)
        get "/admin/services", selected: connection.id.to_s

        expect(page.find(".li", text: "Google Health")).to have_css(".pill", text: "needs reconnect")
        expect(page).to have_css("form[action='/admin/services/google_health/connect'] button", text: "Reconnect")
      end

      it "asks Google nothing more until I reconnect", :aggregate_failures do
        expect { read }.to raise_error(Health::Error)
        expect { read }.to raise_error(Health::Error, "Google Health needs a reconnect")

        expect(a_request(:post, token_url)).to have_been_made.once
      end

      it "clears the mark when I reconnect", :aggregate_failures do
        expect { read }.to raise_error(Health::Error)
        stub_token({ access_token: "ya29.again", expires_in: 3599, refresh_token: "1//again", token_type: "Bearer" })
        callback(code: "code", state: start_connect)

        expect(connection.revoked_at).to be_nil
        expect(connection.credentials).to include(access_token: "ya29.again", refresh_token: "1//again")
      end
    end

    describe "once connected" do
      before { connect_account }

      it "reports that Google Health answers a test" do
        stub_steps("ya29.old")
        post "/admin/services/#{connection.id}/test", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(toast).to include("Google Health answered")
      end

      it "revokes the token on Google when I disconnect", :aggregate_failures do
        revoke = stub_request(:post, "https://oauth2.googleapis.com/revoke").with(body: { token: "1//refresh" })
        post "/admin/services/#{connection.id}/disconnect", _csrf_token: admin_csrf_token

        expect(revoke).to have_been_made
        expect(connection).to be_nil
      end
    end
  end
end

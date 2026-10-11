# frozen_string_literal: true

RSpec.describe "Admin Google connection", type: :request do
  let(:asked) do
    %w[openid userinfo.email gmail.modify gmail.send calendar.events googlehealth.sleep.readonly]
      .map { it == "openid" ? it : "https://www.googleapis.com/auth/#{it}" }
  end
  let(:sleep_scope) { "https://www.googleapis.com/auth/googlehealth.sleep.readonly" }
  let(:steps_url) { "https://health.googleapis.com/v4/users/me/dataTypes/steps/dataPoints?page_size=1" }
  let(:token_url) { "https://oauth2.googleapis.com/token" }
  let(:userinfo_url) { "https://openidconnect.googleapis.com/v1/userinfo" }

  before { sign_in_to_admin }

  def account(account_id) = connections.find { it.account_id == account_id }

  def authorize_query = Rack::Utils.parse_query(URI(last_response.location).query)

  def callback(**) = get("/admin/auth/google/callback", **)

  def client = Google::Slice["google.client"]

  def connect_account(account_id: "me", expires_at: Time.now.to_i + 3600, revoked_at: nil, scopes: [sleep_scope])
    Services::Slice["repos.connection_mutations"].add(
      provider: "google", account_id:, label: account_id, revoked_at:, scopes:,
      credentials: { access_token: "ya29.old", expires_at:, refresh_token: "1//refresh" },
    )
  end

  def connection = connections.first

  def connections = Services::Slice["repos.connection_queries"].for(:google)

  def grant(email, scopes, access_token: "ya29.new")
    stub_token({ access_token:, expires_in: 3599, refresh_token: "1//#{email}", token_type: "Bearer" }
      .merge(scope: scopes.join(" ")))
    stub_request(:get, userinfo_url)
      .with(headers: { "Authorization" => "Bearer #{access_token}" })
      .to_return(json({ email: }))
  end

  def json(body) = { headers: { "Content-Type" => "application/json" }, body: body.to_json }

  def page = Capybara.string(last_response.body)

  def pickable = page.all("#connect-service .svc-pick .svc-line-name", visible: :all).map(&:text)

  def read(account_id) = client.get(steps_url, account: account_id)

  def reconnect_field = "form[action='/admin/services/google/connect'] input[value='#{connection.id}']"

  def scope_line(label) = page.find(".svc-line", text: label)

  def start_connect(**)
    post("/admin/services/google/connect", _csrf_token: admin_csrf_token, **)
    authorize_query.fetch("state")
  end

  def stub_steps(token, status: 200)
    stub_request(:get, steps_url)
      .with(headers: { "Authorization" => "Bearer #{token}" })
      .to_return(status:, **json({}))
  end

  def stub_token(body, status: 200) = stub_request(:post, token_url).to_return(status:, **json(body))

  def toast = page.find("[data-toast]").text

  describe "without client credentials in settings" do
    before { set_up_google_client({}) }

    it "lists Google as not set up and leaves it out of the picker", :aggregate_failures do
      get "/admin/services"

      expect(page.find(".svc-group", text: "Health")).to have_css(".li", text: /Google.*not set up/)
      expect(pickable).not_to include("Google")
    end

    it "names the missing settings on its detail" do
      get "/admin/services", selected: "google"

      expect(page.find(".svc-line", text: "GOOGLE_CLIENT_ID")).to have_css(".pill", text: "missing")
    end

    it "refuses to start a connect", :aggregate_failures do
      post "/admin/services/google/connect", _csrf_token: admin_csrf_token
      follow_redirect!

      expect(toast).to include("Google sign-in isn't set up")
      expect(connection).to be_nil
    end

    it "reads nothing from Google" do
      expect(read("me")).to be_nil
    end
  end

  describe "with client credentials in settings" do
    before { set_up_google_client }

    it "offers Google in the picker" do
      get "/admin/services"

      expect(pickable).to include("Google")
    end

    describe "starting" do
      before { start_connect }

      it "sends me to Google asking offline and letting me pick the account", :aggregate_failures do
        expect(last_response.location).to start_with("https://accounts.google.com/o/oauth2/v2/auth?")
        expect(authorize_query).to include(
          "client_id" => "google-id", "access_type" => "offline", "prompt" => "select_account consent",
        )
      end

      it "asks for the address, mail, calendar and Health" do
        expect(authorize_query.fetch("scope").split).to include(*asked)
      end

      it "sends a PKCE challenge and comes back to the Google callback", :aggregate_failures do
        expect(authorize_query).to include("code_challenge_method" => "S256")
        expect(authorize_query.fetch("redirect_uri")).to end_with("/admin/auth/google/callback")
      end
    end

    describe "when Google grants access" do
      before do
        grant("aaron@example.com", [sleep_scope])
        callback(code: "code", state: start_connect)
        follow_redirect!
      end

      it "names the account by its address and keeps the refresh token sealed", :aggregate_failures do
        expect(connection).to have_attributes(account_id: "aaron@example.com", label: "aaron@example.com")
        expect(connection.credentials).to include(access_token: "ya29.new", refresh_token: "1//aaron@example.com")
        expect(connection.scopes).to eq([sleep_scope])
      end

      it "queues a Health backfill from today" do
        expect(Health::Jobs::BackfillHealth.jobs.map { it["args"] }).to eq([[Blog::TimeZone.today.iso8601]])
      end

      it "opens the account as connected", :aggregate_failures do
        expect(toast).to include("Google connected as aaron@example.com")
        expect(page.find(".settings-side")).to have_css(".pill", text: "connected")
        expect(scope_line("Read sleep")).to have_css(".pill", text: "granted")
      end

      it "still offers Google in the picker for another account" do
        expect(pickable).to include("Google")
      end
    end

    describe "connecting a second and a third account" do
      before do
        connect_account(account_id: "aaron@example.com")
        grant("work@example.com", %w[openid https://www.googleapis.com/auth/gmail.modify], access_token: "ya29.work")
        callback(code: "code", state: start_connect)
        grant("other@example.com", %w[https://www.googleapis.com/auth/calendar.events], access_token: "ya29.other")
        callback(code: "code", state: start_connect)
      end

      it "keeps each account as its own row with its own scopes", :aggregate_failures do
        expect(connections.map(&:account_id)).to contain_exactly(
          "aaron@example.com", "work@example.com", "other@example.com",
        )
        expect(account("work@example.com").scopes).to eq(%w[openid https://www.googleapis.com/auth/gmail.modify])
        expect(account("other@example.com").scopes).to eq(%w[https://www.googleapis.com/auth/calendar.events])
      end

      it "queues no Health backfill for accounts that did not grant Health" do
        expect(Health::Jobs::BackfillHealth.jobs).to be_empty
      end

      it "shows each account's own scopes", :aggregate_failures do
        get "/admin/services", selected: account("work@example.com").id.to_s

        expect(scope_line("Read, label and archive mail")).to have_css(".pill", text: "granted")
        expect(scope_line("Read sleep")).to have_button("Grant")
      end
    end

    describe "an account missing a scope" do
      before { connect_account }

      it "shows Grant, which reconnects that account" do
        get "/admin/services", selected: connection.id.to_s

        expect(scope_line("Send mail as you")).to have_css(reconnect_field, visible: :all)
      end

      it "adds the scope to the same account when Google grants it", :aggregate_failures do
        scopes = [sleep_scope, "https://www.googleapis.com/auth/gmail.send"]
        grant("aaron@example.com", scopes)

        expect { callback(code: "code", state: start_connect(connection: connection.id)) }
          .not_to(change { connections.map(&:id) })
        expect(connection).to have_attributes(account_id: "aaron@example.com", scopes:)
      end
    end

    it "saves nothing when I decline on Google", :aggregate_failures do
      callback(error: "access_denied", state: start_connect)
      follow_redirect!

      expect(connection).to be_nil
      expect(toast).to include("Google didn't grant access")
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
        read("me")
      end

      it "refreshes it and reads with the new one" do
        refreshed = hash_including("grant_type" => "refresh_token", "refresh_token" => "1//refresh")

        expect(a_request(:post, token_url).with(body: refreshed)).to have_been_made
      end

      it "writes the new access token back and keeps the refresh token" do
        expect(connection.credentials).to include(access_token: "ya29.fresh", refresh_token: "1//refresh")
      end
    end

    it "refreshes and tries again when Google turns down a token that has not expired" do
      connect_account
      stub_steps("ya29.old", status: 401)
      stub_token({ access_token: "ya29.fresh", expires_in: 3599, token_type: "Bearer" })
      stub_steps("ya29.fresh")

      expect(read("me")).to eq({})
    end

    it "refuses to read for an account it does not hold" do
      expect { read("nobody@example.com") }.to raise_error(Google::Error, "nobody@example.com isn't connected")
    end

    describe "when Google has revoked the refresh token" do
      before do
        connect_account(expires_at: Time.now.to_i - 60)
        stub_token({ error: "invalid_grant" }, status: 400)
      end

      it "marks the account as needing a reconnect", :aggregate_failures do
        expect { read("me") }.to raise_error(Google::Error, "me needs a reconnect")
        expect(connection.revoked_at).not_to be_nil
      end

      it "offers to reconnect that account", :aggregate_failures do
        expect { read("me") }.to raise_error(Google::Error)
        get "/admin/services", selected: connection.id.to_s

        expect(page.find(".li", text: "Google")).to have_css(".pill", text: "needs reconnect")
        expect(page.find(".svc-actions")).to have_css(reconnect_field, visible: :all)
      end

      it "asks Google nothing more until I reconnect", :aggregate_failures do
        2.times { expect { read("me") }.to raise_error(Google::Error, "me needs a reconnect") }

        expect(a_request(:post, token_url)).to have_been_made.once
      end

      it "clears the mark on the same account when I reconnect", :aggregate_failures do
        expect { read("me") }.to raise_error(Google::Error)
        grant("aaron@example.com", [sleep_scope], access_token: "ya29.again")
        callback(code: "code", state: start_connect(connection: connection.id))

        expect(connections).to contain_exactly(have_attributes(revoked_at: nil, account_id: "aaron@example.com"))
      end
    end

    describe "once connected" do
      before do
        connect_account
        connect_account(account_id: "work@example.com")
      end

      it "reports that the account answers a test" do
        stub_request(:get, userinfo_url).to_return(json({ email: "aaron@example.com" }))
        post "/admin/services/#{connection.id}/test", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(toast).to include("Google answered")
      end

      it "revokes one account on Google when I disconnect it and leaves the others", :aggregate_failures do
        revoke = stub_request(:post, "https://oauth2.googleapis.com/revoke").with(body: { token: "1//refresh" })
        post "/admin/services/#{account('me').id}/disconnect", _csrf_token: admin_csrf_token

        expect(revoke).to have_been_made.once
        expect(connections.map(&:account_id)).to eq(["work@example.com"])
      end
    end
  end
end

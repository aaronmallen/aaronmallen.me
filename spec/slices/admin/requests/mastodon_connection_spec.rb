# frozen_string_literal: true

RSpec.describe "Admin Mastodon connection", type: :request do
  let(:apps_url) { "https://ruby.social/api/v1/apps" }
  let(:revoke_url) { "https://ruby.social/oauth/revoke" }
  let(:scope) { "write:statuses write:media read:accounts read:search read:statuses" }

  before do
    sign_in_to_admin
    resolves_publicly("ruby.social")
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

  def start_connect(server = "ruby.social")
    post "/admin/services/mastodon/connect", server:, _csrf_token: admin_csrf_token
    authorize_query["state"]
  end

  it "asks for my server in the picker" do
    get "/admin/settings/services"

    expect(page).to have_css("form[action='/admin/services/mastodon/connect'] input[name='server']", visible: :all)
  end

  it "continues to my server from the dialog footer, beside a cancel that only closes it", :aggregate_failures do
    get "/admin/settings/services"
    dialog = page.find_by_id("connect-service-mastodon", visible: :all)

    expect(dialog).to have_css(".dialog-foot [type='submit'][form='connect-service-mastodon-form']", visible: :all)
    expect(dialog).to have_css("form#connect-service-mastodon-form input[name='server']", visible: :all)
    expect(dialog).to have_css(".dialog-foot button[type='button'][data-dialog-close]", text: "Cancel", visible: :all)
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

    it "refuses a server that resolves to a private address and sends nothing", :aggregate_failures do
      resolves("ruby.social", "192.168.1.20")
      start_connect
      follow_redirect!

      expect(a_request(:any, /.*/)).not_to have_been_made
      expect(page).to have_css("[data-toast]", text: "That isn't a server name")
    end

    it "refuses a loopback address given as the server and sends nothing", :aggregate_failures do
      start_connect("127.0.0.1")
      follow_redirect!

      expect(a_request(:any, /.*/)).not_to have_been_made
      expect(page).to have_css("[data-toast]", text: "That isn't a server name")
    end

    it "does not follow the server when it redirects the app registration", :aggregate_failures do
      stub_request(:post, apps_url).to_return(status: 307, headers: { "Location" => "http://10.0.0.5/api/v1/apps" })
      start_connect
      follow_redirect!

      expect(a_request(:any, /10\.0\.0\.5/)).not_to have_been_made
      expect(page).to have_css("[data-toast]", text: "didn't answer as Mastodon")
    end

    it "refuses a server that does not answer as Mastodon", :aggregate_failures do
      stub_request(:post, apps_url).to_return(status: 404)
      start_connect
      follow_redirect!

      expect(last_request.path).to eq("/admin/settings/services")
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
      Social::Slice["social_networks.all"].fetch("mastodon").post("Hello", idempotency_key: "key")

      expect(posted).to have_been_made
    end

    it "does not follow a post the server redirects", :aggregate_failures do
      stub_request(:post, SocialNetworks::MASTODON_STATUSES)
        .to_return(status: 307, headers: { "Location" => "http://10.0.0.5/api/v1/statuses" })
      mastodon = Social::Slice["social_networks.all"].fetch("mastodon")

      expect { mastodon.post("Hello", idempotency_key: "key") }.to raise_error(Mastodon::Error)
      expect(a_request(:any, /10\.0\.0\.5/)).not_to have_been_made
    end
  end

  describe "reconnecting an account it holds" do
    let!(:held) do
      Services::Slice["repos.connection_mutations"].add(
        provider: "mastodon", host: "ruby.social", account_id: "109", label: "@old@ruby.social",
        credentials: { access_token: "stale" }, scopes: [],
      )
    end
    let!(:delivery) do
      social_post = Social::Slice["repos.social_post_mutations"].create_with_parts(
        parts: %w[later], targets: %w[mastodon], status: "scheduled", posted_at: Time.now + 3600,
      )
      create(:social_post_delivery, :mastodon, social_post_id: social_post.id, connection_id: held.id)
    end

    before do
      callback(code: "code", state: start_connect)
      follow_redirect!
    end

    it "replaces the token on the same connection", :aggregate_failures do
      expect(connections.map(&:id)).to eq([held.id])
      expect(connections.first.label).to eq("@aaronmallen@ruby.social")
      expect(connections.first.credentials).to include(access_token: "masto-token", client_id: "app-id")
    end

    it "keeps the account on its scheduled posts" do
      kept = Social::Slice["relations.social_post_deliveries"].where(id: delivery.id).one

      expect(kept).to include(connection_id: held.id)
    end

    it "adds the same account on another server as its own connection" do
      Services::Slice["relations.service_connections"].where(id: held.id).update(host: "hachyderm.io")
      callback(code: "code", state: start_connect)

      expect(connections.map(&:host)).to contain_exactly("hachyderm.io", "ruby.social")
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

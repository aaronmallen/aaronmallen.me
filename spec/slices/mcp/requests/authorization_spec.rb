# frozen_string_literal: true

RSpec.describe "OAuth authorization", type: :request do
  let(:client) { mcp_create(:oauth_client, client_name: "Claude") }
  let(:i18n) { MCP::Slice["i18n"] }
  let(:verifier) { Blog::SecretToken.generate }

  def approve = approve_authorization(authorize_path)

  def authorize(**overrides) = get(authorize_path(**overrides))

  def authorize_path(**overrides)
    params = {
      client_id: client.client_id,
      code_challenge: challenge,
      code_challenge_method: "S256",
      redirect_uri:,
      resource: "https://aaronmallen.me/mcp",
      response_type: "code",
      scope: "read suggest",
      state: "state-from-claude",
    }.merge(overrides).compact

    "/oauth/authorize?#{Rack::Utils.build_query(params)}"
  end

  def callback = Rack::Utils.parse_query(URI(last_response.location).query)

  def cancel = cancel_authorization(authorize_path)

  def challenge = MCP::OAuth::PKCE.challenge(verifier)

  def code = codes.one

  def codes = MCP::Slice["db.rom"].relations[:oauth_codes]

  def copy(key, **) = i18n.t(key, scope: "ui.views.authorizations.new", **)

  def document = JSON.parse(last_response.body)

  def mcp_create(name, *traits, **) = Spec::DB::Factories[:mcp].create(name, *traits, **)

  def page = Capybara.string(last_response.body)

  def policy = last_response.headers["Content-Security-Policy"].split(";")

  def redirect_uri = client.redirect_uris.first

  def sign_in_as(github_user_id)
    stub_github_sign_in
    stub_request(:get, "https://api.github.com/user")
      .to_return(headers: { "Content-Type" => "application/json" }, body: { id: github_user_id }.to_json)
    get "/admin/sign-in"
    get "/admin/auth/github/callback", code: "code", state: callback.fetch("state")
  end

  describe "when I am signed out" do
    it "sends me to GitHub sign-in" do
      authorize

      expect(last_response.location).to eq("/admin/sign-in")
    end

    it "issues no code" do
      authorize

      expect(codes.count).to eq(0)
    end

    it "comes back to the authorization request once I am signed in" do
      authorize
      sign_in_to_admin_with_github

      expect(last_response.location).to eq(authorize_path)
    end

    it "asks me to approve after sign-in" do
      authorize
      sign_in_to_admin
      get authorize_path

      expect(page).to have_css("form[action='/oauth/authorize']")
    end

    it "refuses an approval it never showed me" do
      post "/oauth/authorize", { client_id: client.client_id, decision: "approve", redirect_uri: }

      expect(codes.count).to eq(0)
    end
  end

  describe "when I signed out and a copied cookie asks" do
    before do
      sign_in_to_admin
      cookie = rack_mock_session.cookie_jar.get_cookie(Blog::SessionCookie::KEY).raw
      post "/admin/sign-out", _csrf_token: admin_csrf_token
      clear_cookies
      set_cookie cookie
    end

    it "sends me to GitHub sign-in" do
      authorize

      expect(last_response.location).to eq("/admin/sign-in")
    end
  end

  describe "when another GitHub account signs in" do
    before do
      authorize
      sign_in_as(12_345)
    end

    it "refuses the sign-in" do
      expect(last_response.status).to eq(403)
    end

    it "asks for sign-in again" do
      authorize

      expect(last_response.location).to eq("/admin/sign-in")
    end

    it "issues no code" do
      authorize

      expect(codes.count).to eq(0)
    end
  end

  describe "when I am signed in and the client asks" do
    before do
      sign_in_to_admin
      authorize
    end

    it "answers with a page" do
      expect(last_response.status).to eq(200)
    end

    it "issues no code" do
      expect(codes.count).to eq(0)
    end

    it "sends me nowhere" do
      expect(last_response.location).to be_nil
    end

    it "leads with the host the code goes to" do
      expect(page.find("h1").text).to eq(copy(:heading, host: "claude.ai"))
    end

    it "gives the client name as the name it gave itself" do
      expect(page.find(".page-head-sub").text).to eq(copy(:named, client: "Claude"))
    end

    it "keeps the client name out of the heading" do
      expect(page.find("h1").text).not_to include("Claude")
    end

    it "warns of no write access it did not ask for" do
      expect(page).to have_no_css(".connect-warn")
    end

    it "names the access it grants" do
      expect(page).to have_text("Read everything the site keeps")
        .and(have_text("Send you suggested edits to accept or reject"))
    end

    it "leaves out the access the client did not ask for" do
      expect(page).to have_no_text("Make any change the admin makes")
    end

    it "carries the scopes through to the approval" do
      expect(authorization_fields).to include("scope" => "read suggest")
    end

    it "names where the client sends me back" do
      expect(page).to have_text(redirect_uri)
    end

    it "offers approve and cancel" do
      expect(page).to have_button("Approve", name: "decision", value: "approve")
        .and(have_button("Cancel", name: "decision", value: "cancel"))
    end

    it "carries a CSRF token" do
      expect(page).to have_css("form input[name='_csrf_token']", visible: :hidden)
    end

    it "keeps the browser from indexing the page" do
      expect(last_response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
    end

    it "keeps another site from framing the page" do
      expect(policy).to include("frame-ancestors 'none'")
    end

    it "keeps the rest of the content security policy" do
      expect(policy).to include("default-src 'none'", "script-src 'self'", "object-src 'none'")
    end

    it "lets the form send me back to any redirect URI a client can register" do
      expect(policy).to include("form-action 'self' https: http:")
    end
  end

  describe "when the client asks to read" do
    before do
      sign_in_to_admin
      authorize(scope: "read")
    end

    it "says the journal and every commit cross rather than naming the feed" do
      expect(page).to have_text("your journal").and(have_text("every commit you have made, whole message and all"))
    end

    it "says a private repository crosses too" do
      expect(page).to have_text("whole message and all, private and work repositories included")
    end
  end

  describe "when the client asks to write" do
    before do
      sign_in_to_admin
      authorize(scope: "read write")
    end

    it "keeps publishing, sending and deleting out of the write grant" do
      expect(page.find("li", text: "Make any change the admin makes").text)
        .to include("short of publishing, sending and deleting")
    end

    it "shows no warning" do
      expect(page).to have_no_css(".connect-warn")
    end
  end

  describe "when the client asks to publish and delete" do
    before do
      sign_in_to_admin
      authorize(scope: "read write publish delete")
    end

    it "shows a line for publishing" do
      expect(page).to have_css("li", text: copy(:"scopes.publish"))
    end

    it "shows a line for deleting" do
      expect(page).to have_css("li", text: copy(:"scopes.delete"))
    end

    it "warns that it can publish and send for good" do
      expect(page.find(".connect-warn").text).to eq(copy(:publish_warning))
    end

    it "puts the warning on the publish grant" do
      expect(page.find("li", text: copy(:"scopes.publish"))).to have_css(".connect-warn")
    end
  end

  describe "when the client has never held a token" do
    let(:client) { mcp_create(:oauth_client, client_name: "Claude", created_at: Time.new(2026, 9, 3, 15, 4, 0, "UTC")) }

    before do
      sign_in_to_admin
      authorize
    end

    it "says the client is new and when it registered" do
      expect(page.find(".connect-notice").text).to eq(copy(:new_client, time: "Sep 3, 2026, 10:04"))
    end

    it "puts when it registered in a time tag" do
      expect(page.find(".connect-notice time")[:datetime]).to eq("2026-09-03T10:04:00-05:00")
    end
  end

  describe "when the client holds a token" do
    before do
      mcp_create(:oauth_token, oauth_client_id: client.id)
      sign_in_to_admin
      authorize
    end

    it "shows no new client notice" do
      expect(page).to have_no_css(".connect-notice")
    end
  end

  describe "when the client used a token it no longer holds" do
    let(:client) { mcp_create(:oauth_client, client_name: "Claude", last_used_at: Time.now - 86_400) }

    before do
      sign_in_to_admin
      authorize
    end

    it "shows no new client notice" do
      expect(page).to have_no_css(".connect-notice")
    end
  end

  describe "when the client registered no name" do
    before do
      sign_in_to_admin
      authorize(client_id: mcp_create(:oauth_client, client_name: nil).client_id)
    end

    it "still leads with the redirect URI host" do
      expect(page.find("h1").text).to eq(copy(:heading, host: "claude.ai"))
    end

    it "says the client gave no name" do
      expect(page.find(".page-head-sub").text).to eq(copy(:unnamed))
    end
  end

  describe "when the client registered a redirect URI that does not parse" do
    let(:client) { mcp_create(:oauth_client, client_name: nil, redirect_uris: ["not a uri"]) }

    before do
      sign_in_to_admin
      authorize
    end

    it "still asks me to approve" do
      expect(last_response).to be_ok
    end

    it "asks to approve the app rather than naming a host it cannot read" do
      expect(page.find("h1").text).to eq(copy(:heading_no_host))
    end

    it "says the client gave no name" do
      expect(page.find(".page-head-sub").text).to eq(copy(:unnamed))
    end
  end

  describe "when the client registered a padded redirect URI" do
    let(:client) { register(" https://claude.ai/api/mcp/auth_callback") }

    def clients = MCP::Slice["db.rom"].relations[:oauth_clients].with(auto_struct: true)

    def register(uri)
      post "/oauth/register", { redirect_uris: [uri] }.to_json, "CONTENT_TYPE" => "application/json"
      clients.with_client_id(document.fetch("client_id")).one
    end

    it "stores the URI it validated" do
      expect(client.redirect_uris).to eq(["https://claude.ai/api/mcp/auth_callback"])
    end

    it "links the error back to the client rather than raising" do
      sign_in_to_admin
      authorize(response_type: "token")

      expect(page.find_link("Go back to claude.ai")[:href]).to start_with("#{redirect_uri}?")
    end

    it "issues no code when it refuses the request" do
      sign_in_to_admin
      authorize(response_type: "token")

      expect(codes.count).to eq(0)
    end

    it "sends me back to the client once I approve" do
      sign_in_to_admin
      approve

      expect(last_response.location).to start_with("#{redirect_uri}?")
    end

    it "ties the code to the URI it validated" do
      sign_in_to_admin
      approve

      expect(code[:redirect_uri]).to eq(redirect_uri)
    end

    it "rejects the padded form the client sent to register" do
      authorize(redirect_uri: " https://claude.ai/api/mcp/auth_callback")

      expect(last_response.status).to eq(400)
    end
  end

  describe "when I approve" do
    before do
      sign_in_to_admin
      approve
    end

    it "sends me back to the client" do
      expect(last_response.location).to start_with("#{redirect_uri}?")
    end

    it "hands the client a code" do
      expect(callback["code"]).to be_a(String).and(satisfy { !it.empty? })
    end

    it "gives back the state the client sent" do
      expect(callback["state"]).to eq("state-from-claude")
    end

    it "names itself as the issuer" do
      expect(callback["iss"]).to eq("https://aaronmallen.me")
    end

    it "stores the code hashed" do
      expect(code[:code_digest]).to eq(Blog::SecretToken.digest(callback.fetch("code")))
    end

    it "stores no plain text code" do
      expect(code.to_h.values.map(&:to_s)).not_to include(callback.fetch("code"))
    end

    it "ties the code to the client" do
      expect(code[:oauth_client_id]).to eq(client.id)
    end

    it "ties the code to the redirect URI" do
      expect(code[:redirect_uri]).to eq(redirect_uri)
    end

    it "ties the code to the PKCE challenge" do
      expect(code[:code_challenge]).to eq(challenge)
    end

    it "ties the code to the resource" do
      expect(code[:resource]).to eq("https://aaronmallen.me/mcp")
    end

    it "ties the code to the scopes I approved" do
      expect(code[:scopes]).to eq(%w[read suggest])
    end

    it "expires the code within a minute" do
      expect(code[:expires_at]).to be_between(Time.now, Time.now + 60)
    end

    it "leaves the code unused" do
      expect(code[:used_at]).to be_nil
    end
  end

  describe "when the client asks for a scope" do
    before { sign_in_to_admin }

    it "grants reading alone when the client asks for nothing" do
      approve_authorization(authorize_path(scope: nil))

      expect(code[:scopes]).to eq(%w[read])
    end

    it "shows reading alone when the client asks for nothing" do
      authorize(scope: nil)

      expect(page).to have_text("Read everything the site keeps")
    end

    it "shows every admin write when the client asks to write" do
      authorize(scope: "read write")

      expect(page).to have_text("Make any change the admin makes")
    end

    it "grants every scope a client asks for by name" do
      approve_authorization(authorize_path(scope: "read suggest write publish delete"))

      expect(code[:scopes]).to eq(%w[read suggest write publish delete])
    end

    it "drops a scope it does not know" do
      approve_authorization(authorize_path(scope: "read erase"))

      expect(code[:scopes]).to eq(%w[read])
    end

    it "shows what the token will carry, not what the client asked for" do
      authorize(scope: "read erase")

      expect(page).to have_no_text("erase")
    end
  end

  describe "when the client names no resource" do
    before do
      sign_in_to_admin
      approve_authorization(authorize_path(resource: nil))
    end

    it "sends me back to the client" do
      expect(last_response.location).to start_with("#{redirect_uri}?")
    end

    it "ties the code to this server anyway" do
      expect(code[:resource]).to eq("https://aaronmallen.me/mcp")
    end
  end

  describe "when I cancel" do
    before do
      sign_in_to_admin
      cancel
    end

    it "sends me back to the client" do
      expect(last_response.location).to start_with("#{redirect_uri}?")
    end

    it "tells the client I said no" do
      expect(callback["error"]).to eq("access_denied")
    end

    it "gives back the state the client sent" do
      expect(callback["state"]).to eq("state-from-claude")
    end

    it "names itself as the issuer" do
      expect(callback["iss"]).to eq("https://aaronmallen.me")
    end

    it "hands the client no code" do
      expect(callback["code"]).to be_nil
    end

    it "issues no code" do
      expect(codes.count).to eq(0)
    end
  end

  describe "when the approval comes late" do
    let(:signed_in_at) { Time.now }

    before do
      sign_in_to_admin
      lapse(Blog::SessionCookie::LIFETIME / 2)
      get authorize_path
    end

    def approve_with = post("/oauth/authorize", authorization_fields.merge("decision" => "approve"))

    def lapse(seconds) = allow(Time).to(receive(:now).and_return(signed_in_at + seconds))

    it "refuses an approval from a session that lapsed" do
      lapse(Blog::SessionCookie::LIFETIME)
      approve_with

      expect(last_response.status).to eq(403)
    end

    it "issues no code from a session that lapsed" do
      lapse(Blog::SessionCookie::LIFETIME)
      approve_with

      expect(codes.count).to eq(0)
    end

    it "rejects a client revoked since the page loaded" do
      MCP::Slice["db.rom"].relations[:oauth_clients].update(revoked_at: Time.now)
      approve_with

      expect(document["error"]).to eq("invalid_client")
    end

    it "issues no code for a client revoked since the page loaded" do
      MCP::Slice["db.rom"].relations[:oauth_clients].update(revoked_at: Time.now)
      approve_with

      expect(codes.count).to eq(0)
    end
  end

  describe "when the approval carries the wrong CSRF token" do
    before { sign_in_to_admin }

    def decide(token)
      get authorize_path
      post "/oauth/authorize", authorization_fields.merge("_csrf_token" => token, "decision" => "approve").compact
    end

    it "refuses a forged token" do
      decide("forged")

      expect(last_response.status).to eq(403)
    end

    it "issues no code for a forged token" do
      decide("forged")

      expect(codes.count).to eq(0)
    end

    it "refuses a missing token" do
      decide(nil)

      expect(last_response.status).to eq(403)
    end

    it "issues no code for a missing token" do
      decide(nil)

      expect(codes.count).to eq(0)
    end

    it "says the form expired" do
      decide("forged")

      expect(page).to have_text("Form expired")
    end
  end

  describe "a request it refuses" do
    context "when an approval swaps in a bad response_type" do
      before do
        sign_in_to_admin
        get authorize_path
        post "/oauth/authorize", authorization_fields.merge("decision" => "approve", "response_type" => "token")
      end

      it "answers with a page" do
        expect(page).to have_link("Go back to claude.ai")
      end

      it "issues no code" do
        expect(codes.count).to eq(0)
      end
    end

    {
      "response_type is not code" => { response_type: "token" },
      "the PKCE challenge is missing" => { code_challenge: nil },
      "the PKCE challenge is too short" => { code_challenge: "short" },
      "the PKCE method is not S256" => { code_challenge_method: "plain" },
      "the resource names another server" => { resource: "https://example.com/mcp" },
    }.each do |description, overrides|
      context "when #{description} and I am signed out" do
        before { authorize(**overrides) }

        it "sends me to GitHub sign-in" do
          expect(last_response.location).to eq("/admin/sign-in")
        end

        it "issues no code" do
          expect(codes.count).to eq(0)
        end
      end

      context "when #{description} and I am signed in" do
        before do
          sign_in_to_admin
          authorize(**overrides)
        end

        def link = page.find_link("Go back to claude.ai")

        def linked = Rack::Utils.parse_query(URI(link[:href]).query)

        it "answers with a page" do
          expect(last_response.status).to eq(400)
        end

        it "sends me nowhere" do
          expect(last_response.location).to be_nil
        end

        it "names the error" do
          expect(page).to have_text("#{linked.fetch('error_description')} (#{linked.fetch('error')}).")
        end

        it "names the redirect host" do
          expect(page).to have_text("The app at claude.ai sent a request")
        end

        it "links to the redirect URI" do
          expect(link[:href]).to start_with("#{redirect_uri}?")
        end

        it "tells the client the error through the link" do
          expect(linked["error"]).to be_a(String).and(satisfy { !it.empty? })
        end

        it "gives back the state through the link" do
          expect(linked["state"]).to eq("state-from-claude")
        end

        it "keeps another site from framing the page" do
          expect(policy).to include("frame-ancestors 'none'")
        end

        it "issues no code" do
          expect(codes.count).to eq(0)
        end
      end
    end
  end

  describe "a request it refuses to send anywhere" do
    before { sign_in_to_admin }

    def unknown_client_id = "11111111-0000-4000-8000-999999999999"

    it "rejects an unknown client" do
      authorize(client_id: unknown_client_id)

      expect(last_response.status).to eq(400)
    end

    it "names the client as the problem" do
      authorize(client_id: unknown_client_id)

      expect(document["error"]).to eq("invalid_client")
    end

    it "rejects a client that was revoked" do
      authorize(client_id: mcp_create(:oauth_client, :revoked).client_id)

      expect(document["error"]).to eq("invalid_client")
    end

    it "rejects a redirect URI the client never registered" do
      authorize(redirect_uri: "https://elsewhere.example/callback")

      expect(document["error"]).to eq("invalid_request")
    end

    it "issues no code" do
      authorize(redirect_uri: "https://elsewhere.example/callback")

      expect(codes.count).to eq(0)
    end

    it "takes the only registered redirect URI when the client sends none" do
      approve_authorization(authorize_path(redirect_uri: nil))

      expect(last_response.location).to start_with("#{redirect_uri}?")
    end

    it "rejects the request when the client registered more than one and sends none" do
      two = mcp_create(:oauth_client, redirect_uris: %w[https://claude.ai/one https://claude.ai/two])
      authorize(client_id: two.client_id, redirect_uri: nil)

      expect(last_response.status).to eq(400)
    end
  end

  describe "a client_id that is not a UUID" do
    ["\0", "not-a-uuid", "#{SecureRandom.uuid}\n"].each do |client_id|
      context "when #{client_id.inspect} comes in while I am signed out" do
        before { authorize(client_id:) }

        it "rejects it" do
          expect(last_response.status).to eq(400)
        end

        it "names the client as the problem" do
          expect(document["error"]).to eq("invalid_client")
        end
      end

      context "when #{client_id.inspect} comes in while I am signed in" do
        before do
          sign_in_to_admin
          authorize(client_id:)
        end

        it "rejects it" do
          expect(last_response.status).to eq(400)
        end

        it "names the client as the problem" do
          expect(document["error"]).to eq("invalid_client")
        end
      end

      context "when an approval swaps in #{client_id.inspect}" do
        before do
          sign_in_to_admin
          get authorize_path
          post "/oauth/authorize", authorization_fields.merge("client_id" => client_id, "decision" => "approve")
        end

        it "rejects it" do
          expect(last_response.status).to eq(400)
        end

        it "names the client as the problem" do
          expect(document["error"]).to eq("invalid_client")
        end

        it "issues no code" do
          expect(codes.count).to eq(0)
        end
      end
    end
  end

  describe "a field it cannot read" do
    before { sign_in_to_admin }

    def linked = Rack::Utils.parse_query(URI(page.find_link("Go back to claude.ai")[:href]).query)

    {
      "a scope with a double space" => [{ scope: "read  suggest" }, "invalid_scope"],
      "a scope that opens with a space" => [{ scope: " read" }, "invalid_scope"],
      "a scope holding a NUL" => [{ scope: "read\u0000" }, "invalid_scope"],
      "a scope holding a quote" => [{ scope: "read\"suggest" }, "invalid_scope"],
      "a PKCE challenge one character too long" => [{ code_challenge: "a" * 129 }, "invalid_request"],
      "a PKCE challenge holding a slash" => [{ code_challenge: "#{'a' * 42}/" }, "invalid_request"],
      "an empty PKCE challenge" => [{ code_challenge: "" }, "invalid_request"],
      "an empty PKCE method" => [{ code_challenge_method: "" }, "invalid_request"],
      "an empty response_type" => [{ response_type: "" }, "unsupported_response_type"],
      "a resource on another path of this server" => [{ resource: "https://aaronmallen.me/admin" }, "invalid_target"],
      "a resource on a host that only starts the same" =>
        [{ resource: "https://aaronmallen.me.evil.example/mcp" }, "invalid_target"],
      "an empty resource" => [{ resource: "" }, "invalid_target"],
      "a wrong response_type and no PKCE challenge" =>
        [{ response_type: "token", code_challenge: nil }, "unsupported_response_type"],
    }.each do |description, (overrides, error)|
      it "answers #{error} for #{description}" do
        authorize(**overrides)

        expect(linked["error"]).to eq(error)
      end
    end

    { "scope" => "invalid_scope", "state" => "invalid_request", "code_challenge" => "invalid_request" }
      .each do |field, error|
        it "answers #{error} for a #{field} sent as a list" do
          get "#{authorize_path(field.to_sym => nil)}&#{field}[]=one&#{field}[]=two"

          expect(linked["error"]).to eq(error)
        end
      end

    ["state\u0000", "state\n", "sta\u00e9te"].each do |state|
      it "names the state as the problem for #{state.inspect}" do
        authorize(state:)

        expect(linked["error_description"]).to eq(MCP::Operations::Authorize::UNUSABLE_STATE)
      end

      it "keeps #{state.inspect} out of the link" do
        authorize(state:)

        expect(linked).not_to include("state")
      end
    end

    it "gives back the state when it refuses another field" do
      authorize(response_type: "token")

      expect(linked).to include("state" => "state-from-claude")
    end

    it "checks the client before the rest of the request" do
      authorize(client_id: nil, response_type: "token")

      expect(document["error"]).to eq("invalid_client")
    end
  end

  describe "a field it takes" do
    before { sign_in_to_admin }

    {
      "a resource with a trailing slash" => { resource: "https://aaronmallen.me/mcp/" },
      "the issuer itself as the resource" => { resource: "https://aaronmallen.me" },
      "an empty state" => { state: "" },
      "no PKCE method, state, resource or scope" =>
        { code_challenge_method: nil, resource: nil, scope: nil, state: nil },
    }.each do |description, overrides|
      it "issues a code for #{description}" do
        approve_authorization(authorize_path(**overrides))

        expect(callback).to include("code")
      end
    end

    it "grants reading alone for an empty scope" do
      approve_authorization(authorize_path(scope: ""))

      expect(code[:scopes]).to eq(%w[read])
    end

    it "grants a scope once when the client names it twice" do
      approve_authorization(authorize_path(scope: "write write"))

      expect(code[:scopes]).to eq(%w[write])
    end

    it "grants the scopes in its own order" do
      approve_authorization(authorize_path(scope: "write read"))

      expect(code[:scopes]).to eq(%w[read write])
    end

    it "grants a scope on its own without reading" do
      approve_authorization(authorize_path(scope: "suggest"))

      expect(code[:scopes]).to eq(%w[suggest])
    end

    it "sends no state back when the client sent none" do
      approve_authorization(authorize_path(state: nil))

      expect(callback).not_to include("state")
    end
  end

  describe "an approval the operation fails for a reason the action does not know" do
    before do
      sign_in_to_admin
      get authorize_path
      failing = instance_double(MCP::Operations::Authorize, call: Dry::Monads::Failure(:gone_wrong))
      replace_component("operations.authorize", failing)
      post "/oauth/authorize", authorization_fields.merge("decision" => "approve")
    end

    it "answers 400 rather than raising" do
      expect(last_response.status).to eq(400)
    end

    it "names the request as the problem" do
      expect(document["error"]).to eq("invalid_request")
    end
  end

  describe "a redirect URI that carries a query" do
    let(:client) { mcp_create(:oauth_client, redirect_uris: ["https://claude.ai/callback?next=1&state=theirs"]) }

    before do
      sign_in_to_admin
      approve
    end

    it "keeps the query the client registered" do
      expect(last_response.location).to start_with("https://claude.ai/callback?next=1&")
    end

    it "sends back the state the request carried rather than the one registered" do
      expect(callback["state"]).to eq("state-from-claude")
    end
  end
end

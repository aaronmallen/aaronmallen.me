# frozen_string_literal: true

RSpec.describe "Admin sessions", type: :request do
  let(:email) { Spec::AdminSession::EMAIL }
  let(:page) { Capybara.string(last_response.body) }
  let(:thirty_days) { 30 * 24 * 60 * 60 }
  let(:token_response) { { access_token: "gho_token", scope: "", token_type: "bearer" } }

  before do
    connect_github(client_id: "client-id", client_secret: "client-secret")

    stub_request(:post, "http://stub.localhost/github/login/oauth/access_token")
      .to_return(headers: { "Content-Type" => "application/json" }, body: token_response.to_json)

    stub_request(:get, "http://stub.localhost/github/api/user/emails")
      .with(headers: { "Authorization" => "Bearer gho_token" })
      .to_return(
        headers: { "Content-Type" => "application/json" },
        body: [{ email: "old@example.com", primary: false, verified: true }, { email:, primary: true, verified: true }]
          .to_json,
      )
  end

  def authorize_query
    Rack::Utils.parse_query(URI(last_response.location).query)
  end

  def callback(**params)
    get "/admin/auth/github/callback", params
  end

  def cookie_session = Spec::AdminSession.encryptor.decrypt(session_cookie.value)

  def device_cookie = rack_mock_session.cookie_jar.get_cookie(Blog::DeviceCookie::KEY)

  def live_session_cookie?
    !session_cookie.nil? && !session_cookie.expired?
  end

  def restore(raw)
    clear_cookies
    set_cookie raw
  end

  def session_cookie
    rack_mock_session.cookie_jar.get_cookie(Blog::SessionCookie::KEY)
  end

  def sign_in(path = "/admin")
    state = start_sign_in(path)
    callback(code: "code", state:)
  end

  def signed_out?
    get "/admin"
    last_response.location.to_s.end_with?("/admin/sign-in")
  end

  def start_sign_in(path = "/admin")
    get path
    start_admin_sign_in("github")
  end

  def token_request
    a_request(:post, "http://stub.localhost/github/login/oauth/access_token")
  end

  def verifier_matches?(request, challenge)
    verifier = Rack::Utils.parse_query(request.body)["code_verifier"].to_s
    Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) == challenge
  end

  describe "signed out" do
    before { get "/admin/posts?page=2" }

    it "renders a page with a GitHub button and a Google button", :aggregate_failures do
      follow_redirect!

      expect(page.find("form[action='/admin/sign-in/github'] button")).to have_text("Sign in with GitHub")
      expect(page.find("form[action='/admin/sign-in/google'] button")).to have_text("Sign in with Google")
    end

    it "lets the sign-in forms follow their redirect to an authorize page on any https origin" do
      follow_redirect!

      expect(last_response.headers["Content-Security-Policy"][/form-action [^;]*/]).to eq("form-action 'self' https:")
    end

    it "sends the GitHub button on to GitHub" do
      start_admin_sign_in("github")

      expect(last_response.location).to start_with("http://stub.localhost/github/login/oauth/authorize?")
    end

    it "asks GitHub for a code for the operator's OAuth app" do
      start_admin_sign_in("github")

      expect(authorize_query).to include("client_id" => "client-id", "response_type" => "code")
    end

    it "asks GitHub to read the account's email addresses and nothing more" do
      start_admin_sign_in("github")

      expect(authorize_query).to include("scope" => "user:email")
    end

    it "asks GitHub to come back to the callback on the site the settings name" do
      start_admin_sign_in("github")

      expect(authorize_query).to include("redirect_uri" => "https://aaronmallen.me/admin/auth/github/callback")
    end

    it "asks GitHub not to offer sign-up" do
      start_admin_sign_in("github")

      expect(authorize_query).to include("allow_signup" => "false")
    end

    it "sends GitHub a state to check on the way back" do
      expect(start_admin_sign_in("github").length).to be >= 32
    end

    it "sends GitHub an S256 code challenge", :aggregate_failures do
      start_admin_sign_in("github")

      expect(authorize_query).to include("code_challenge_method" => "S256")
      expect(authorize_query.fetch("code_challenge")).to match(/\A[\w-]{43}\z/)
    end

    it "refuses to start a sign-in without a CSRF token" do
      post "/admin/sign-in/github"

      expect(last_response.status).to eq(403)
    end

    it "tells search engines not to index the redirect" do
      expect(last_response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
    end
  end

  describe "signing in as the operator" do
    it "opens the admin URL first asked for" do
      sign_in("/admin?tab=today")

      expect(last_response.location).to end_with("/admin?tab=today")
    end

    it "opens /admin after a signed-out tab asked for the event stream" do
      get "/admin/events"
      sign_in("/admin/sign-in")

      expect(last_response.location).to end_with("/admin")
    end

    it "opens /admin when no admin URL was asked for" do
      sign_in("/admin/sign-in")

      expect(last_response.location).to end_with("/admin")
    end

    it "renders a missing admin page as not found" do
      sign_in
      get "/admin/nowhere"

      expect(last_response).to be_not_found
    end

    it "renders a missing admin page as the admin's not found page" do
      sign_in
      get "/admin/nowhere"

      expect(last_response.body).to include("<title>Page not found | Admin | Aaron Allen</title>")
    end

    it "renders the admin" do
      sign_in
      follow_redirect!

      expect(last_response).to be_ok
    end

    it "sends noindex with the admin", :aggregate_failures do
      sign_in
      follow_redirect!

      expect(last_response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
      expect(last_response.body).to include('<meta name="robots" content="noindex, nofollow">')
    end

    it "renders the sign-out form with a CSRF token" do
      sign_in
      follow_redirect!

      token = page.find("#avatar-menu form[action='/admin/sign-out'] input[name='_csrf_token']", visible: :all)

      expect(token.value).to match(/\A\h{64}\z/)
    end

    it "keeps the email in the session cookie in place of a GitHub id", :aggregate_failures do
      sign_in

      expect(cookie_session).to include("email" => email)
      expect(cookie_session).not_to have_key("github_user_id")
    end

    it "sets a session cookie that expires in 30 days" do
      now = Time.at(Time.now.to_i)
      allow(Time).to receive(:now).and_return(now)
      sign_in

      expect(session_cookie.expires).to eq(now + thirty_days)
    end
  end

  describe "the code GitHub hands back" do
    it "goes back with the verifier behind the challenge" do
      state = start_sign_in
      challenge = authorize_query.fetch("code_challenge")
      callback(code: "code", state:)

      expect(token_request.with { verifier_matches?(it, challenge) }).to have_been_made
    end
  end

  describe "a code swapped in from another sign-in" do
    before do
      start_sign_in
      challenge = authorize_query.fetch("code_challenge")
      state = start_sign_in
      stub_request(:post, "http://stub.localhost/github/login/oauth/access_token")
        .to_return(status: 400, headers: { "Content-Type" => "application/json" }, body: { error: "bad" }.to_json)
      stub_request(:post, "http://stub.localhost/github/login/oauth/access_token")
        .with { verifier_matches?(it, challenge) }
        .to_return(headers: { "Content-Type" => "application/json" }, body: token_response.to_json)
      callback(code: "code", state:)
    end

    it "renders an error page" do
      expect(last_response.status).to eq(502)
    end

    it "stays signed out" do
      expect(signed_out?).to be(true)
    end
  end

  describe "a sign-in started with no verifier" do
    before do
      started = Spec::AdminSession.encryptor.encrypt("oauth_states" => ["legacy-state"])
      restore("#{Blog::SessionCookie::KEY}=#{Rack::Utils.escape(started)}")
      callback(code: "code", state: "legacy-state")
    end

    it "renders an error page" do
      expect(last_response.status).to eq(401)
    end

    it "never asks GitHub for a token" do
      expect(token_request).not_to have_been_made
    end
  end

  describe "signing in with an owner email in another case" do
    let(:email) { Spec::AdminSession::EMAIL.upcase }

    it "opens the admin" do
      sign_in

      expect(last_response.location).to end_with("/admin")
    end
  end

  describe "signing in as another GitHub account" do
    let(:email) { "stranger@example.com" }

    before { sign_in }

    it "renders an error page", :aggregate_failures do
      expect(last_response.status).to eq(403)
      expect(last_response.body).to include("This GitHub account can")
    end

    it "sets no session cookie" do
      expect(live_session_cookie?).to be(false)
    end

    it "stays signed out" do
      expect(signed_out?).to be(true)
    end
  end

  describe "signing in as a GitHub account whose owner email is not its primary" do
    before do
      stub_request(:get, "http://stub.localhost/github/api/user/emails").to_return(
        headers: { "Content-Type" => "application/json" },
        body: [
          { email: "stranger@example.com", primary: true, verified: true }, { email:, primary: false, verified: true },
        ].to_json,
      )
      sign_in
    end

    it "turns the account away" do
      expect(last_response.status).to eq(403)
    end
  end

  describe "signing in as a GitHub account whose primary email is not verified" do
    before do
      stub_github_emails(email, verified: false)
      sign_in
    end

    it "turns the account away", :aggregate_failures do
      expect(last_response.status).to eq(403)
      expect(signed_out?).to be(true)
    end

    it "says on the sign-in page that the email must be verified and an owner's" do
      get "/admin/sign-in"

      expect(page).to have_css(".page-head-sub", exact_text: Admin::Slice["i18n"].t("ui.views.sessions.new.sub"))
    end
  end

  describe "signing in as a GitHub account with no emails" do
    before do
      stub_request(:get, "http://stub.localhost/github/api/user/emails")
        .to_return(headers: { "Content-Type" => "application/json" }, body: "[]")
      sign_in
    end

    it "turns the account away" do
      expect(last_response.status).to eq(403)
    end
  end

  describe "signing in as a second owner" do
    let(:email) { "second@example.com" }

    before do
      Admin::Slice["repos.owner_identity_mutations"].add(email)
      sign_in
    end

    it "opens the admin" do
      expect(last_response.location).to end_with("/admin")
    end
  end

  describe "with no owners" do
    let(:owners) { Admin::Slice["db.rom"].gateways[:default].connection[:owner_identities] }

    it "turns the account away" do
      owners.delete
      sign_in

      expect(last_response.status).to eq(403)
    end

    it "ends a session that was signed in" do
      sign_in
      owners.delete

      expect(signed_out?).to be(true)
    end
  end

  describe "a denied callback" do
    before { callback(error: "access_denied", state: start_sign_in) }

    it "renders an error page", :aggregate_failures do
      expect(last_response.status).to eq(401)
      expect(last_response.body).to include("GitHub sign-in did not finish")
    end

    it "stays signed out" do
      expect(signed_out?).to be(true)
    end

    it "never asks GitHub for a token" do
      expect(token_request).not_to have_been_made
    end
  end

  describe "a callback carrying no code" do
    before { callback(code: "", state: start_sign_in) }

    it "renders an error page", :aggregate_failures do
      expect(last_response.status).to eq(401)
      expect(last_response.body).to include("GitHub sign-in did not finish")
    end

    it "never asks GitHub for a token" do
      expect(token_request).not_to have_been_made
    end
  end

  describe "a callback with a forged state" do
    let!(:state) { start_sign_in }

    before { callback(code: "code", state: "forged") }

    it "renders an error page" do
      expect(last_response.status).to eq(401)
    end

    it "never asks GitHub for a token" do
      expect(token_request).not_to have_been_made
    end

    it "leaves the sign-in in flight the state it went out with" do
      callback(code: "code", state:)

      expect(last_response.location).to end_with("/admin")
    end
  end

  describe "a callback after the sign-in state expired" do
    let!(:state) { start_sign_in }

    def callback_after(seconds)
      allow(Time).to receive(:now).and_return(Time.at(Time.now.to_i + seconds))
      callback(code: "code", state:)
    end

    it "renders an error page" do
      callback_after(Admin::Auth::ConnectState::LIFETIME)

      expect(last_response.status).to eq(401)
    end

    it "never asks GitHub for a token" do
      callback_after(Admin::Auth::ConnectState::LIFETIME)

      expect(token_request).not_to have_been_made
    end

    it "signs in while the state is still fresh" do
      callback_after(Admin::Auth::ConnectState::LIFETIME - 5)

      expect(last_response.location).to end_with("/admin")
    end
  end

  describe "a callback replayed" do
    let!(:state) { start_sign_in }

    before { callback(code: "code", state:) }

    it "sends the second time to the admin" do
      callback(code: "code", state:)

      expect(last_response.location).to end_with("/admin")
    end

    it "asks GitHub for no second token" do
      callback(code: "code", state:)

      expect(token_request).to have_been_made.once
    end

    it "refuses the second time a minute or more later" do
      allow(Time).to receive(:now).and_return(Time.now + 60)
      callback(code: "code", state:)

      expect(last_response.status).to eq(401)
    end

    it "stays signed in" do
      callback(code: "code", state:)

      expect(signed_out?).to be(false)
    end
  end

  describe "two sign-ins started in two tabs" do
    let!(:tabs) { [start_sign_in, start_sign_in] }

    it "signs in from the tab opened first" do
      callback(code: "code", state: tabs.first)

      expect(signed_out?).to be(false)
    end

    it "signs in from the tab opened second" do
      callback(code: "code", state: tabs.last)

      expect(signed_out?).to be(false)
    end

    it "sends the other tab to the admin once one of them signed in" do
      callback(code: "code", state: tabs.first)
      callback(code: "code", state: tabs.last)

      expect(last_response.location).to end_with("/admin")
    end

    it "stays signed in when the other tab comes back" do
      callback(code: "code", state: tabs.first)
      callback(code: "code", state: tabs.last)

      expect(signed_out?).to be(false)
    end
  end

  describe "a sixth sign-in started while five wait" do
    let!(:tabs) { Array.new(6) { start_sign_in } }

    it "refuses the tab opened first" do
      callback(code: "code", state: tabs.first)

      expect(last_response.status).to eq(401)
    end

    it "signs in from the tab opened last" do
      callback(code: "code", state: tabs.last)

      expect(signed_out?).to be(false)
    end
  end

  describe "a callback without a started sign-in" do
    before { callback(code: "code", state: "forged") }

    it "renders an error page" do
      expect(last_response.status).to eq(401)
    end
  end

  describe "a stray callback while signed in" do
    before { sign_in }

    it "sends the browser that just signed in to the admin" do
      callback(code: "code", state: "forged")

      expect(last_response.location).to end_with("/admin")
    end

    it "asks GitHub for no further token" do
      callback(code: "code", state: "forged")

      expect(token_request).to have_been_made.once
    end

    it "still answers the admin" do
      callback(code: "code", state: "forged")
      get "/admin"

      expect(last_response).to be_ok
    end

    it "stays signed in on a mismatched state" do
      callback(code: "code", state: "forged")

      expect(signed_out?).to be(false)
    end

    it "stays signed in on a missing state" do
      callback(code: "code")

      expect(signed_out?).to be(false)
    end

    it "stays signed in on an empty state" do
      callback(code: "code", state: "")

      expect(signed_out?).to be(false)
    end
  end

  describe "a callback for another GitHub account while signed in" do
    before do
      sign_in
      stub_github_emails("stranger@example.com")
      sign_in("/admin/sign-in")
    end

    it "renders an error page" do
      expect(last_response.status).to eq(403)
    end

    it "ends the session" do
      expect(signed_out?).to be(true)
    end
  end

  describe "a failed callback" do
    context "when GitHub rejects the code" do
      let(:token_response) { { error: "bad_verification_code" } }

      before { sign_in }

      it "renders an error page", :aggregate_failures do
        expect(last_response.status).to eq(502)
        expect(last_response.body).to include("GitHub could not confirm who you are")
      end

      it "stays signed out" do
        expect(signed_out?).to be(true)
      end
    end

    context "when GitHub calls the token JSON and sends something else" do
      before do
        stub_request(:post, "http://stub.localhost/github/login/oauth/access_token")
          .to_return(headers: { "Content-Type" => "application/json" }, body: "<html>Our proxy is down</html>")
        sign_in
      end

      it "renders an error page", :aggregate_failures do
        expect(last_response.status).to eq(502)
        expect(last_response.body).to include("GitHub could not confirm who you are")
      end

      it "stays signed out" do
        expect(signed_out?).to be(true)
      end
    end

    context "when GitHub calls the token XML and sends something else" do
      before do
        stub_request(:post, "http://stub.localhost/github/login/oauth/access_token")
          .to_return(headers: { "Content-Type" => "application/xml" }, body: token_response.to_json)
        sign_in
      end

      it "renders an error page" do
        expect(last_response.status).to eq(502)
      end
    end

    context "when GitHub fails to return the emails" do
      before do
        stub_request(:get, "http://stub.localhost/github/api/user/emails").to_return(status: 503)
        sign_in
      end

      it "renders an error page" do
        expect(last_response.status).to eq(502)
      end
    end

    context "when GitHub answers the emails with a page instead of JSON" do
      before do
        stub_request(:get, "http://stub.localhost/github/api/user/emails")
          .to_return(headers: { "Content-Type" => "text/html" }, body: "<html>Our proxy is down</html>")
        sign_in
      end

      it "renders an error page", :aggregate_failures do
        expect(last_response.status).to eq(502)
        expect(last_response.body).to include("GitHub could not confirm who you are")
      end

      it "stays signed out" do
        expect(signed_out?).to be(true)
      end
    end

    context "when GitHub calls the emails JSON and sends something else" do
      before do
        stub_request(:get, "http://stub.localhost/github/api/user/emails")
          .to_return(headers: { "Content-Type" => "application/json" }, body: "<html>Our proxy is down</html>")
        sign_in
      end

      it "renders an error page" do
        expect(last_response.status).to eq(502)
      end
    end

    context "when GitHub times out" do
      before do
        stub_request(:post, "http://stub.localhost/github/login/oauth/access_token").to_timeout
        sign_in
      end

      it "renders an error page" do
        expect(last_response.status).to eq(502)
      end
    end
  end

  describe "the device cookie" do
    let(:devices) { Security::Slice["db.rom"].gateways[:default].connection[:devices] }

    it "sets one on sign-in that names the new device and only /admin reads", :aggregate_failures do
      sign_in

      expect([device_cookie.value, device_cookie.path]).to eq([devices.get(:id), "/admin"])
      expect(device_cookie).to be_http_only
    end

    it "sets one that lives 400 days" do
      now = Time.at(Time.now.to_i)
      allow(Time).to receive(:now).and_return(now)
      sign_in

      expect(device_cookie.expires).to eq(now + (400 * 24 * 60 * 60))
    end

    it "keeps the one a browser already holds" do
      sign_in
      held = device_cookie.value
      post "/admin/sign-out", _csrf_token: admin_csrf_token
      sign_in

      expect([device_cookie.value, devices.count]).to eq([held, 1])
    end

    it "swaps an ID that names no device for a fresh one", :aggregate_failures do
      guessed = SecureRandom.uuid
      set_cookie "#{Blog::DeviceCookie::KEY}=#{guessed}; path=/admin"
      sign_in

      expect(device_cookie.value).not_to eq(guessed)
      expect(devices.select_map(:id)).to eq([device_cookie.value])
    end

    it "swaps a value that is no ID for a fresh one" do
      set_cookie "#{Blog::DeviceCookie::KEY}=not-an-id; path=/admin"
      sign_in

      expect(devices.select_map(:id)).to eq([device_cookie.value])
    end

    it "stays when signing out" do
      sign_in
      held = device_cookie.value
      post "/admin/sign-out", _csrf_token: admin_csrf_token

      expect(device_cookie.value).to eq(held)
    end

    it "is neither sent to nor set by a public page", :aggregate_failures do
      sign_in
      get "/"

      expect(last_request.cookies).not_to have_key(Blog::DeviceCookie::KEY)
      expect(last_response.headers["set-cookie"].to_s).not_to include(Blog::DeviceCookie::KEY)
    end
  end

  describe "signing out" do
    before do
      sign_in
      post "/admin/sign-out", _csrf_token: admin_csrf_token
    end

    it "redirects to the home page" do
      expect(last_response.location).to eq("/")
    end

    it "removes the session cookie" do
      expect(live_session_cookie?).to be(false)
    end

    it "asks for sign-in again" do
      expect(signed_out?).to be(true)
    end
  end

  describe "a cookie copied before signing out" do
    before do
      sign_in
      cookie = session_cookie.raw
      post "/admin/sign-out", _csrf_token: admin_csrf_token
      restore(cookie)
    end

    it "asks for sign-in again" do
      expect(signed_out?).to be(true)
    end
  end

  describe "signing out on one device" do
    before do
      sign_in
      cookie = session_cookie.raw
      clear_cookies
      sign_in
      post "/admin/sign-out", _csrf_token: admin_csrf_token
      restore(cookie)
    end

    it "ends the session on the other one" do
      expect(signed_out?).to be(true)
    end
  end

  describe "signing out a device from the security tab" do
    let!(:phone) do
      sign_in
      { device: device_cookie.value, session: session_cookie.raw }.tap do
        clear_cookies
        sign_in
      end
    end

    def device_count = Security::Slice["db.rom"].gateways[:default].connection[:devices].count

    def sign_in_on_phone
      restore(phone[:session])
      set_cookie "#{Blog::DeviceCookie::KEY}=#{phone[:device]}; path=/admin"
      allow(Time).to receive(:now).and_return(Time.now + 1)
      sign_in
    end

    def sign_out_device(id) = post("/admin/settings/security/devices/#{id}/sign-out", _csrf_token: admin_csrf_token)

    before { sign_out_device(phone[:device]) }

    it "ends that browser's session on its next request" do
      restore(phone[:session])

      expect(signed_out?).to be(true)
    end

    it "keeps the other devices signed in" do
      expect(signed_out?).to be(false)
    end

    it "lets that browser sign in again as the same device", :aggregate_failures do
      sign_in_on_phone

      expect(signed_out?).to be(false)
      expect([device_cookie.value, device_count]).to eq([phone[:device], 2])
    end

    it "ends the session of the browser that signs out its own device" do
      sign_out_device(device_cookie.value)

      expect(signed_out?).to be(true)
    end

    it "returns 404 for a device that is not there" do
      sign_out_device(SecureRandom.uuid)

      expect(last_response).to be_not_found
    end
  end

  describe "a session whose device is gone" do
    before do
      sign_in
      Security::Slice["db.rom"].gateways[:default].connection[:devices].delete
    end

    it "asks for sign-in again" do
      expect(signed_out?).to be(true)
    end
  end

  describe "signing out without a CSRF token" do
    before do
      sign_in
      post "/admin/sign-out"
    end

    it "renders an error page", :aggregate_failures do
      expect(last_response.status).to eq(403)
      expect(page).to have_css(".page-head h1", text: "Form expired")
    end

    it "renders the page in the admin layout" do
      expect(page).to have_css("header.top-bar .pill-nav")
    end

    it "sends noindex with the error page" do
      expect(last_response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
    end

    it "stays signed in" do
      expect(signed_out?).to be(false)
    end
  end

  describe "signing out with a forged CSRF token" do
    before do
      sign_in
      post "/admin/sign-out", _csrf_token: "forged"
    end

    it "renders an error page" do
      expect(last_response.status).to eq(403)
    end

    it "stays signed in" do
      expect(signed_out?).to be(false)
    end
  end

  describe "signing out with another session's CSRF token" do
    before do
      sign_in
      token = admin_csrf_token
      clear_cookies
      sign_in
      post "/admin/sign-out", _csrf_token: token
    end

    it "renders an error page" do
      expect(last_response.status).to eq(403)
    end
  end

  describe "signing out with the CSRF token in a header" do
    before do
      sign_in
      token = admin_csrf_token
      post "/admin/sign-out", {}, "HTTP_X_CSRF_TOKEN" => token
    end

    it "redirects to the home page" do
      expect(last_response.location).to eq("/")
    end
  end

  describe "a POST without a CSRF token while signed out" do
    before { post "/admin/sign-out" }

    it "renders an error page" do
      expect(last_response.status).to eq(403)
    end

    it "renders no pills" do
      expect(page).to have_no_css(".pill-nav")
    end
  end

  describe "a session older than 30 days" do
    before do
      sign_in
      cookie = session_cookie.raw
      allow(Time).to receive(:now).and_return(Time.now + thirty_days)
      restore(cookie)
    end

    it "asks for sign-in again" do
      expect(signed_out?).to be(true)
    end
  end

  describe "with the OAuth settings blank" do
    before do
      connect_github(client_id: nil, client_secret: nil)
    end

    it "renders public pages without a session cookie", :aggregate_failures do
      get "/"

      expect(last_response).to be_ok
      expect(last_response.headers["set-cookie"]).to be_nil
    end

    it "still renders the sign-in page" do
      get "/admin/sign-in"

      expect(last_response).to be_ok
    end

    it "renders an error page instead of sending anyone to GitHub", :aggregate_failures do
      get "/admin/sign-in"
      post "/admin/sign-in/github", _csrf_token: admin_csrf_token

      expect(last_response.status).to eq(503)
      expect(last_response.body).to include("GitHub sign-in is not set up yet")
    end
  end

  describe "signing in with Google" do
    before do
      set_up_google_client
      stub_request(:post, "http://stub.localhost/google/oauth/token").to_return(
        headers: { "Content-Type" => "application/json" },
        body: { access_token: "ya29.sign-in", expires_in: 3599, token_type: "Bearer" }.to_json,
      )
      stub_userinfo(email:, email_verified: true)
    end

    def connections = Services::Slice["db.rom"].gateways[:default].connection[:service_connections]

    def google_callback(**params) = get("/admin/auth/google/callback", params)

    def google_sign_in(path = "/admin")
      get path
      google_callback(code: "code", state: start_admin_sign_in("google"))
    end

    def stub_userinfo(**userinfo)
      stub_request(:get, "http://stub.localhost/google/openid/userinfo")
        .with(headers: { "Authorization" => "Bearer ya29.sign-in" })
        .to_return(headers: { "Content-Type" => "application/json" }, body: userinfo.to_json)
    end

    it "sends the Google button on to Google" do
      start_admin_sign_in("google")

      expect(last_response.location).to start_with("http://stub.localhost/google/accounts/o/oauth2/v2/auth?")
    end

    it "asks Google for openid and email and nothing more" do
      start_admin_sign_in("google")

      expect(authorize_query.fetch("scope")).to eq("openid email")
    end

    it "sends Google an S256 code challenge", :aggregate_failures do
      start_admin_sign_in("google")

      expect(authorize_query).to include("code_challenge_method" => "S256")
      expect(authorize_query.fetch("code_challenge")).to match(/\A[\w-]{43}\z/)
    end

    it "sends Google the verifier behind the challenge with the code" do
      state = start_admin_sign_in("google")
      challenge = authorize_query.fetch("code_challenge")
      google_callback(code: "code", state:)

      expect(a_request(:post, "http://stub.localhost/google/oauth/token").with { verifier_matches?(it, challenge) })
        .to have_been_made
    end

    it "asks Google to come back to its own sign-in callback" do
      start_admin_sign_in("google")

      expect(authorize_query).to include("redirect_uri" => "https://aaronmallen.me/admin/auth/google/callback")
    end

    it "opens the admin URL first asked for" do
      google_sign_in("/admin?tab=today")

      expect(last_response.location).to end_with("/admin?tab=today")
    end

    it "keeps the email in the session cookie" do
      google_sign_in

      expect(cookie_session).to include("email" => email)
    end

    it "stays signed in" do
      google_sign_in

      expect(signed_out?).to be(false)
    end

    it "writes no connected service" do
      google_sign_in

      expect(connections.count).to eq(0)
    end

    context "when Google has not verified the email" do
      before do
        stub_userinfo(email:, email_verified: false)
        google_sign_in
      end

      it "renders an error page", :aggregate_failures do
        expect(last_response.status).to eq(403)
        expect(last_response.body).to include("This Google account can")
      end

      it "stays signed out" do
        expect(signed_out?).to be(true)
      end
    end

    context "when the email is not an owner's" do
      it "renders an error page" do
        stub_userinfo(email: "stranger@example.com", email_verified: true)
        google_sign_in

        expect(last_response.status).to eq(403)
      end
    end

    context "when Google rejects the code" do
      before do
        stub_request(:post, "http://stub.localhost/google/oauth/token").to_return(
          status: 400, headers: { "Content-Type" => "application/json" }, body: { error: "invalid_grant" }.to_json,
        )
        google_sign_in
      end

      it "renders an error page", :aggregate_failures do
        expect(last_response.status).to eq(502)
        expect(last_response.body).to include("Google could not confirm who you are")
      end
    end

    context "when Google answers the user with a page instead of JSON" do
      it "renders an error page" do
        stub_request(:get, "http://stub.localhost/google/openid/userinfo")
          .to_return(headers: { "Content-Type" => "text/html" }, body: "<html>down</html>")
        google_sign_in

        expect(last_response.status).to eq(502)
      end
    end

    context "when the state was minted for no sign-in" do
      it "renders an error page" do
        get "/admin"
        google_callback(code: "code", state: "forged")

        expect(last_response.status).to eq(401)
      end
    end

    context "when Google is not set up" do
      before { set_up_google_client({ client_id: nil, client_secret: nil }) }

      it "renders an error page instead of sending anyone to Google", :aggregate_failures do
        get "/admin/sign-in"
        post "/admin/sign-in/google", _csrf_token: admin_csrf_token

        expect(last_response.status).to eq(503)
        expect(last_response.body).to include("Google sign-in is not set up yet")
      end
    end
  end
end

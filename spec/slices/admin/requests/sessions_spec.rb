# frozen_string_literal: true

RSpec.describe "Admin sessions", type: :request do
  let(:github_user_id) { 931_094 }
  let(:page) { Capybara.string(last_response.body) }
  let(:thirty_days) { 30 * 24 * 60 * 60 }
  let(:token_response) { { access_token: "gho_token", scope: "", token_type: "bearer" } }

  before do
    connect_github(client_id: "client-id", client_secret: "client-secret")

    stub_request(:post, "https://github.com/login/oauth/access_token")
      .to_return(headers: { "Content-Type" => "application/json" }, body: token_response.to_json)

    stub_request(:get, "https://api.github.com/user")
      .with(headers: { "Authorization" => "Bearer gho_token" })
      .to_return(headers: { "Content-Type" => "application/json" }, body: { id: github_user_id }.to_json)
  end

  def authorize_query
    Rack::Utils.parse_query(URI(last_response.location).query)
  end

  def callback(**params)
    get "/admin/auth/github/callback", params
  end

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
    follow_redirect! if last_response.location.end_with?("/admin/sign-in")
    authorize_query.fetch("state")
  end

  def token_request
    a_request(:post, "https://github.com/login/oauth/access_token")
  end

  describe "signed out" do
    before { get "/admin/posts?page=2" }

    it "redirects any admin URL to sign-in" do
      expect(last_response.location).to end_with("/admin/sign-in")
    end

    it "sends sign-in on to GitHub" do
      follow_redirect!

      expect(last_response.location).to start_with("https://github.com/login/oauth/authorize?")
    end

    it "asks GitHub for a code for the operator's OAuth app" do
      follow_redirect!

      expect(authorize_query).to include("client_id" => "client-id", "response_type" => "code")
    end

    it "asks GitHub to come back to the callback on the site the settings name" do
      follow_redirect!

      expect(authorize_query).to include("redirect_uri" => "https://aaronmallen.me/admin/auth/github/callback")
    end

    it "asks GitHub not to offer sign-up" do
      follow_redirect!

      expect(authorize_query).to include("allow_signup" => "false")
    end

    it "sends GitHub a state to check on the way back" do
      follow_redirect!

      expect(authorize_query.fetch("state").length).to be >= 32
    end

    it "tells search engines not to index the redirect" do
      expect(last_response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
    end
  end

  describe "every admin screen signed out" do
    let(:paths) do
      Admin::Slice.routes
      Admin::Routes.definitions.filter_map do |(verb, (path))|
        next if verb != :get || %w[/auth/github/callback /sign-in].include?(path)

        "/admin#{path.gsub(/:\w+/) { it == ':network' ? 'mastodon' : '1' }}".chomp("/")
      end
    end

    it "redirects to sign-in, or answers 401 where a script asks" do
      unguarded = paths.reject do |path|
        get path
        last_response.unauthorized? || last_response.location.to_s.end_with?("/admin/sign-in")
      end

      expect([paths.size, unguarded]).to match([be > 40, []])
    end
  end

  describe "signing in as the operator" do
    it "opens the admin URL first asked for" do
      sign_in("/admin?tab=today")

      expect(last_response.location).to end_with("/admin?tab=today")
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

    it "sets a session cookie that expires in 30 days" do
      now = Time.at(Time.now.to_i)
      allow(Time).to receive(:now).and_return(now)
      sign_in

      expect(session_cookie.expires).to eq(now + thirty_days)
    end
  end

  describe "signing in as another GitHub account" do
    let(:github_user_id) { 1 }

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

  describe "signing in as a second owner" do
    let(:github_user_id) { 42 }

    before do
      Admin::Slice["repos.owner_identity_mutations"].add_github(github_user_id)
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

  describe "a callback replayed" do
    let!(:state) { start_sign_in }

    before { callback(code: "code", state:) }

    it "refuses the second time" do
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

    it "refuses the other tab once one of them signed in" do
      callback(code: "code", state: tabs.first)
      callback(code: "code", state: tabs.last)

      expect(last_response.status).to eq(401)
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

    it "renders an error page" do
      callback(code: "code", state: "forged")

      expect(last_response.status).to eq(401)
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
      stub_request(:get, "https://api.github.com/user")
        .to_return(headers: { "Content-Type" => "application/json" }, body: { id: 1 }.to_json)
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
        stub_request(:post, "https://github.com/login/oauth/access_token")
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
        stub_request(:post, "https://github.com/login/oauth/access_token")
          .to_return(headers: { "Content-Type" => "application/xml" }, body: token_response.to_json)
        sign_in
      end

      it "renders an error page" do
        expect(last_response.status).to eq(502)
      end
    end

    context "when GitHub fails to return the user" do
      before do
        stub_request(:get, "https://api.github.com/user").to_return(status: 503)
        sign_in
      end

      it "renders an error page" do
        expect(last_response.status).to eq(502)
      end
    end

    context "when GitHub answers the user with a page instead of JSON" do
      before do
        stub_request(:get, "https://api.github.com/user")
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

    context "when GitHub calls the user JSON and sends something else" do
      before do
        stub_request(:get, "https://api.github.com/user")
          .to_return(headers: { "Content-Type" => "application/json" }, body: "<html>Our proxy is down</html>")
        sign_in
      end

      it "renders an error page" do
        expect(last_response.status).to eq(502)
      end
    end

    context "when GitHub times out" do
      before do
        stub_request(:post, "https://github.com/login/oauth/access_token").to_timeout
        sign_in
      end

      it "renders an error page" do
        expect(last_response.status).to eq(502)
      end
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

    it "renders an error page instead of sending anyone to GitHub", :aggregate_failures do
      get "/admin/sign-in"

      expect(last_response.status).to eq(503)
      expect(last_response.body).to include("not set up yet")
    end
  end
end

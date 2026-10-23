# frozen_string_literal: true

RSpec.describe "Admin sign-in log", type: :request do
  let(:address) { "81.2.69.160" }
  let(:agent) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36" }
  let(:email) { Spec::AdminSession::EMAIL }
  let(:sign_ins) { Security::Slice["db.rom"].gateways[:default].connection[:sign_ins] }
  let(:token_response) { { access_token: "gho_token" } }

  before do
    connect_oauth_app
    use_country_database
    write_country_database
    allow(Hanami.app.settings).to receive(:proxy)
      .and_return(address_header: "CF-Connecting-IP", trusted_proxies: [IPAddr.new("127.0.0.0/8")])

    stub_request(:post, "http://stub.localhost/github/login/oauth/access_token")
      .to_return(headers: { "Content-Type" => "application/json" }, body: token_response.to_json)
    stub_github_emails(email)
  end

  def callback(user_agent: agent, **params)
    get "/admin/auth/github/callback", params, headers(user_agent)
  end

  def devices = Security::Slice["db.rom"].gateways[:default].connection[:devices]

  def headers(user_agent) = { "HTTP_USER_AGENT" => user_agent, "HTTP_CF_CONNECTING_IP" => address }

  def recorded
    {
      outcome: "signed_in", provider: "github", address:, user_agent: agent, browser: "Chrome", os: "macOS",
      city: "London", country: "GB", country_name: "United Kingdom",
    }
  end

  def sign_in(user_agent: agent) = callback(code: "code", state: start_sign_in, user_agent:)

  def start_sign_in = start_admin_sign_in("github")

  describe "signing in as the operator" do
    it "records the sign-in with its address, device and place" do
      sign_in

      expect(sign_ins.select(*recorded.keys).all).to eq([recorded])
    end

    it "stamps the sign-in with the time it happened" do
      sign_in

      expect(sign_ins.get(:created_at)).to be_within(5).of(Time.now)
    end

    it "keeps no more than 1024 characters of the user agent" do
      sign_in(user_agent: "a" * 2000)

      expect(sign_ins.get(:user_agent).length).to eq(1024)
    end

    it "records a user agent with bytes Postgres can't store" do
      sign_in(user_agent: "Firefox/1\xFF\0".b)

      expect(sign_ins.get(:user_agent)).to eq("Firefox/1\uFFFD")
    end

    it "leaves the browser and OS blank for a user agent it can't read" do
      sign_in(user_agent: "curl/8.7.1")

      expect(sign_ins.select(:browser, :os).first).to eq(browser: nil, os: nil)
    end

    [
      ["Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Version/18.0 Mobile Safari/604.1", "Safari", "iOS"],
      ["Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Gecko/20100101 Firefox/131.0", "Firefox", "Windows"],
      ["Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0", "Edge", "Windows"],
      ["Mozilla/5.0 (Linux; Android 15; Pixel 9) Chrome/141.0.0.0 Mobile Safari/537.36", "Chrome", "Android"],
      ["Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) Chrome/141.0.0.0 Safari/537.36", "Chrome", "ChromeOS"],
      ["Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0", "Firefox", "Linux"],
    ].each do |user_agent, browser, os|
      it "reads #{browser} on #{os} from its user agent" do
        sign_in(user_agent:)

        expect(sign_ins.select(:browser, :os).first).to eq(browser:, os:)
      end
    end
  end

  describe "signing in from one browser three times" do
    before { 3.times { sign_in } }

    it "names one device on every sign-in", :aggregate_failures do
      expect(devices.count).to eq(1)
      expect(sign_ins.select_map(:device_id)).to eq([devices.get(:id)] * 3)
    end

    it "keeps the device's browser and last sign-in time", :aggregate_failures do
      expect(devices.select(:browser, :os).first).to eq(browser: "Chrome", os: "macOS")
      expect(devices.get(:last_signed_in_at)).to be_within(1).of(sign_ins.max(:created_at))
    end
  end

  describe "signing in from two browsers" do
    it "names two devices" do
      sign_in
      clear_cookies
      sign_in(user_agent: "Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0")

      expect(devices.select_order_map(:browser)).to eq(%w[Chrome Firefox])
    end
  end

  describe "a failed callback from a known device" do
    it "names the device on the failure" do
      sign_in
      callback(error: "access_denied", state: start_sign_in)

      expect(sign_ins.where(outcome: "denied").get(:device_id)).to eq(devices.get(:id))
    end
  end

  describe "a failed callback from a browser with no device" do
    it "records no device", :aggregate_failures do
      callback(error: "access_denied", state: start_sign_in)

      expect(sign_ins.get(:device_id)).to be_nil
      expect(devices.count).to eq(0)
    end
  end

  describe "a callback with no matching state" do
    def repeat = callback(code: "code", state: "taken")

    it "writes no row from a device that signed in under a minute ago", :aggregate_failures do
      sign_in
      repeat

      expect(last_response.location).to end_with("/admin")
      expect(sign_ins.select_map(:outcome)).to eq(%w[signed_in])
    end

    it "records a denied sign-in from a device that signed in a minute ago or more", :aggregate_failures do
      sign_in
      devices.update(last_signed_in_at: Time.now - 61)
      repeat

      expect(last_response.status).to eq(401)
      expect(sign_ins.order(:id).select_map(:outcome)).to eq(%w[signed_in denied])
    end

    it "records a denied sign-in from a browser with no device cookie", :aggregate_failures do
      sign_in
      clear_cookies
      repeat

      expect(last_response.status).to eq(401)
      expect(sign_ins.order(:id).select_map(:outcome)).to eq(%w[signed_in denied])
    end

    it "records a denied sign-in from a device cookie that is no ID" do
      set_cookie "#{Blog::DeviceCookie::KEY}=not-an-id; path=/admin"
      repeat

      expect(sign_ins.select_map(:outcome)).to eq(%w[denied])
    end

    it "still records a denied callback whose state matched from a device that just signed in" do
      sign_in
      callback(error: "access_denied", state: start_sign_in)

      expect(sign_ins.order(:id).select_map(:outcome)).to eq(%w[signed_in denied])
    end
  end

  describe "signing in as another GitHub account" do
    let(:email) { "stranger@example.com" }

    it "records a wrong account" do
      sign_in

      expect(sign_ins.select_map(:outcome)).to eq(%w[wrong_account])
    end
  end

  describe "a denied callback" do
    it "records a denied sign-in" do
      callback(error: "access_denied", state: start_sign_in)

      expect(sign_ins.select_map(:outcome)).to eq(%w[denied])
    end
  end

  describe "a callback GitHub fails" do
    let(:token_response) { { error: "bad_verification_code" } }

    it "records a provider failure from GitHub with the address it came from" do
      sign_in

      expect(sign_ins.select(:outcome, :provider, :address).all)
        .to eq([{ outcome: "provider_failed", provider: "github", address: }])
    end
  end

  describe "signing in with Google" do
    before do
      set_up_google_client
      stub_request(:post, "https://oauth2.googleapis.com/token").to_return(
        headers: { "Content-Type" => "application/json" },
        body: { access_token: "ya29.sign-in", expires_in: 3599, token_type: "Bearer" }.to_json,
      )
    end

    def google_sign_in(google_email)
      stub_request(:get, "https://openidconnect.googleapis.com/v1/userinfo").to_return(
        headers: { "Content-Type" => "application/json" }, body: { email: google_email, email_verified: true }.to_json,
      )
      get "/admin/auth/google/callback", { code: "code", state: start_admin_sign_in("google") }, headers(agent)
    end

    it "records the sign-in as Google's" do
      google_sign_in(email)

      expect(sign_ins.select(:outcome, :provider).all).to eq([{ outcome: "signed_in", provider: "google" }])
    end

    it "records a wrong account from Google" do
      google_sign_in("stranger@example.com")

      expect(sign_ins.select(:outcome, :provider).all).to eq([{ outcome: "wrong_account", provider: "google" }])
    end
  end

  describe "a sign-in failing for a reason the callback doesn't know" do
    it "records an unexpected failure" do
      replace_component("operations.sign_in", instance_double(Admin::Operations::SignIn, call: Failure(:odd)))
      sign_in

      expect(sign_ins.select_map(:outcome)).to eq(%w[unexpected])
    end
  end

  describe "a flood of failed callbacks" do
    before { lower_throttle_limit(:sign_ins, to: 2) }

    def fail_callbacks(count = 3) = count.times { callback(code: "code", state: "never-started") }

    it "stops recording failures from one visitor past the limit", :aggregate_failures do
      fail_callbacks

      expect(last_response.status).to eq(401)
      expect(sign_ins.select_map(:outcome)).to eq(%w[denied denied])
    end

    it "counts failures from one IPv6 /64 as one visitor" do
      %w[2001:db8::1 2001:db8::2 2001:db8::3].each do |ipv6|
        get "/admin/auth/github/callback", { state: "never-started" },
            headers(agent).merge("HTTP_CF_CONNECTING_IP" => ipv6)
      end

      expect(sign_ins.count).to eq(2)
    end

    it "still records failures from another visitor" do
      fail_callbacks
      get "/admin/auth/github/callback", {}, headers(agent).merge("HTTP_CF_CONNECTING_IP" => "203.0.113.9")

      expect(sign_ins.where(address: "203.0.113.9").count).to eq(1)
    end

    it "forgets failures older than the window" do
      fail_callbacks
      sign_ins.update(created_at: Time.now - (2 * 60 * 60))
      callback

      expect(sign_ins.count).to eq(3)
    end

    it "always records a sign-in that goes through" do
      fail_callbacks
      sign_in

      expect(sign_ins.select_map(:outcome)).to contain_exactly("denied", "denied", "signed_in")
    end
  end

  describe "a public visit" do
    it "records nothing", :aggregate_failures do
      get "/", {}, headers(agent)
      pulse = { kind: "view", path: "/", title: "Home" }.to_json
      post "/pulse", pulse, { "CONTENT_TYPE" => "application/json", **headers(agent) }

      expect(last_response.status).to be < 400
      expect(sign_ins.count).to eq(0)
    end
  end
end

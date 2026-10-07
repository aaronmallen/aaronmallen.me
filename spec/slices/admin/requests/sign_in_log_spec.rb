# frozen_string_literal: true

RSpec.describe "Admin sign-in log", type: :request do
  let(:address) { "81.2.69.160" }
  let(:agent) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36" }
  let(:github_user_id) { 931_094 }
  let(:sign_ins) { Security::Slice["db.rom"].gateways[:default].connection[:sign_ins] }
  let(:token_response) { { access_token: "gho_token" } }

  before do
    connect_oauth_app
    use_country_database
    write_country_database
    allow(Hanami.app.settings).to receive(:proxy)
      .and_return(address_header: "CF-Connecting-IP", trusted_proxies: [IPAddr.new("127.0.0.0/8")])

    stub_request(:post, "https://github.com/login/oauth/access_token")
      .to_return(headers: { "Content-Type" => "application/json" }, body: token_response.to_json)
    stub_request(:get, "https://api.github.com/user")
      .to_return(headers: { "Content-Type" => "application/json" }, body: { id: github_user_id }.to_json)
  end

  def callback(user_agent: agent, **params)
    get "/admin/auth/github/callback", params, headers(user_agent)
  end

  def headers(user_agent) = { "HTTP_USER_AGENT" => user_agent, "HTTP_CF_CONNECTING_IP" => address }

  def recorded
    { outcome: "signed_in", address:, user_agent: agent, browser: "Chrome", os: "macOS", city: "London", country: "GB" }
  end

  def sign_in(user_agent: agent) = callback(code: "code", state: start_sign_in, user_agent:)

  def start_sign_in
    get "/admin/sign-in"
    Rack::Utils.parse_query(URI(last_response.location).query).fetch("state")
  end

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

  describe "signing in as another GitHub account" do
    let(:github_user_id) { 1 }

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

    it "records a GitHub failure with the address it came from" do
      sign_in

      expect(sign_ins.select(:outcome, :address).all).to eq([{ outcome: "github_failed", address: }])
    end
  end

  describe "a sign-in failing for a reason the callback doesn't know" do
    it "records an unexpected failure" do
      replace_component("operations.sign_in", instance_double(Admin::Operations::SignIn, call: Dry::Monads::Failure(:odd)))
      sign_in

      expect(sign_ins.select_map(:outcome)).to eq(%w[unexpected])
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

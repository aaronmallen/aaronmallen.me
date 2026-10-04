# frozen_string_literal: true

require "securerandom"

RSpec.describe "Secrets a request carries", type: :request do
  let(:client) { Spec::DB::Factories[:mcp].create(:oauth_client) }
  let(:verifier) { MCP::OAuth::Secret.generate }

  before { Hanami.app.start(:honeybadger) }

  def agent = Hanami.app["honeybadger.agent"]

  def crash = @crash ||= Class.new(StandardError)

  def logged
    written = +""
    Hanami.app["logger"].backends.each do |backend|
      allow(backend.formatter).to receive(:call).and_wrap_original do |call, severity, *rest|
        call.call(severity, *rest).tap { written << it unless severity == "DEBUG" }
      end
    end
    yield

    written
  end

  def reported(key)
    notices = []
    replace_component(key, ->(*, **) { raise crash })
    allow(agent.config).to receive(:before_notify_hooks).and_return([->(notice) { notices << notice.to_json }])
    begin
      yield
    rescue crash
      nil
    end

    notices.join("\n")
  end

  def secret = SecureRandom.hex(12)

  describe "GitHub calling the admin back" do
    let(:code) { secret }
    let(:state) do
      get "/admin/sign-in"
      Rack::Utils.parse_query(URI(last_response.location).query).fetch("state")
    end

    def call_back = get("/admin/auth/github/callback", code:, state:)

    before do
      stub_github_sign_in
      state
    end

    it "logs the callback" do
      expect(logged { call_back }).to include("/admin/auth/github/callback")
    end

    it "logs neither the code, the state nor the token GitHub hands back" do
      expect(logged { call_back }).not_to include(code, state, "gho_token")
    end

    it "reports what the callback raised" do
      expect(reported("operations.sign_in") { call_back }).to include("/admin/auth/github/callback")
    end

    it "reports neither the code nor the state" do
      expect(reported("operations.sign_in") { call_back }).not_to include(code, state)
    end
  end

  describe "a client exchanging a code at the MCP token endpoint" do
    let(:client_secret) { secret }
    let(:code) { secret }
    let(:refresh_token) { secret }

    def exchange(code = self.code)
      post "/oauth/token", {
        client_id: client.client_id,
        client_secret:,
        code:,
        code_verifier: verifier,
        grant_type: "authorization_code",
        redirect_uri: client.redirect_uris.first,
      }
    end

    def refresh
      post "/oauth/token", { client_id: client.client_id, grant_type: "refresh_token", refresh_token: }
    end

    it "logs the exchange" do
      issued = mcp_authorization_code(client, verifier:)

      expect(logged { exchange(issued) }).to include("/oauth/token")
    end

    it "logs none of the credentials the exchange carries" do
      issued = mcp_authorization_code(client, verifier:)

      expect(logged { exchange(issued) }).not_to include(issued, verifier, client_secret)
    end

    it "logs none of the tokens it hands out" do
      issued = mcp_authorization_code(client, verifier:)
      log = logged { exchange(issued) }

      expect(log).not_to include(*JSON.parse(last_response.body).values_at("access_token", "refresh_token"))
    end

    it "logs no refresh token" do
      expect(logged { refresh }).not_to include(refresh_token)
    end

    it "reports what the exchange raised" do
      expect(reported("operations.issue_token") { exchange }).to include("/oauth/token")
    end

    it "reports none of the credentials the exchange carries" do
      expect(reported("operations.issue_token") { exchange }).not_to include(code, verifier, client_secret)
    end

    it "reports no refresh token" do
      expect(reported("operations.issue_token") { refresh }).not_to include(refresh_token)
    end
  end

  describe "a client asking the MCP server to authorize it" do
    let(:challenge) { MCP::OAuth::PKCE.challenge(verifier) }
    let(:state) { secret }

    def authorize_path
      params = {
        client_id: client.client_id,
        code_challenge: challenge,
        code_challenge_method: MCP::OAuth::PKCE::METHOD,
        redirect_uri: client.redirect_uris.first,
        response_type: "code",
        state:,
      }

      "#{MCPAuthorize::AUTHORIZE_PATH}?#{Rack::Utils.build_query(params)}"
    end

    def decide = post(MCPAuthorize::AUTHORIZE_PATH, code_challenge: challenge, state:, _csrf_token: admin_csrf_token)

    before { sign_in_to_admin }

    it "logs the request and the decision" do
      log = logged { approve_authorization(authorize_path) }

      expect(log.scan(MCPAuthorize::AUTHORIZE_PATH).size).to be >= 2
    end

    it "logs neither the challenge, the state nor the form token" do
      log = logged { approve_authorization(authorize_path) }

      expect(log).not_to include(challenge, state, admin_csrf_token)
    end

    it "logs none of the code it hands back" do
      log = logged { approve_authorization(authorize_path) }
      code = Rack::Utils.parse_query(URI(last_response.location).query).fetch("code")

      expect(log).not_to include(code)
    end

    it "reports what the request raised" do
      expect(reported("operations.authorize") { get authorize_path }).to include(MCPAuthorize::AUTHORIZE_PATH)
    end

    it "reports neither the challenge nor the state the request carries" do
      expect(reported("operations.authorize") { get authorize_path }).not_to include(challenge, state)
    end

    it "reports neither the challenge, the state nor the form token the decision carries" do
      expect(reported("operations.authorize") { decide }).not_to include(challenge, state, admin_csrf_token)
    end
  end

  describe "a visitor reading the home page" do
    let(:forwarded) { "198.51.100.#{rand(1..254)}" }
    let(:remote) { "203.0.113.#{rand(1..254)}" }

    def visit_home = get("/", {}, "HTTP_X_FORWARDED_FOR" => forwarded, "REMOTE_ADDR" => remote)

    it "logs the request" do
      expect(logged { visit_home }).to match(%r{GET 200 .* / })
    end

    it "logs no visitor address" do
      expect(logged { visit_home }).not_to include(forwarded, remote)
    end

    it "reports no visitor address" do
      expect(reported("posts.queries.latest_published") { visit_home }).not_to include(forwarded, remote)
    end
  end

  describe "the owner capturing a task" do
    let(:note) { secret }

    def capture = post("/admin/tasks", _csrf_token: admin_csrf_token, task: { title: "Call the bank", note: })

    before { sign_in_to_admin }

    it "logs the capture" do
      expect(logged { capture }).to include("/admin/tasks")
    end

    it "logs no task note" do
      expect(logged { capture }).not_to include(note)
    end

    it "reports no task note" do
      expect(reported("tasks.operations.capture_task") { capture }).not_to include(note)
    end
  end

  describe "the owner opening a decision" do
    let(:note) { secret }
    let(:problem) { secret }

    def open_decision
      post "/admin/decisions", _csrf_token: admin_csrf_token, decision: { title: "Pick a host", problem:, note: }
    end

    before { sign_in_to_admin }

    it "logs the decision" do
      expect(logged { open_decision }).to include("/admin/decisions")
    end

    it "logs neither the problem nor the note" do
      expect(logged { open_decision }).not_to include(problem, note)
    end

    it "reports neither the problem nor the note" do
      expect(reported("decisions.operations.open_decision") { open_decision }).not_to include(problem, note)
    end
  end
end

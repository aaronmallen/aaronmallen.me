# frozen_string_literal: true

require "timeout"

RSpec.describe "OAuth token", type: :request do
  let(:client) { mcp_create(:oauth_client) }
  let(:code) { authorization_code }
  let(:verifier) { Blog::Types::NewSecret[] }

  def access_token = tokens.of_type("access").one

  def authorization_code
    sign_in_to_admin
    approve_authorization("/oauth/authorize?#{Rack::Utils.build_query(authorization_params)}")
    Rack::Utils.parse_query(URI(last_response.location).query).fetch("code")
  end

  def authorization_params
    {
      client_id: client.client_id,
      code_challenge: challenge,
      code_challenge_method: "S256",
      redirect_uri:,
      resource:,
      response_type: "code",
      scope: "read suggest",
      state: "state-from-claude",
    }
  end

  def challenge = MCP::Slice["operations.derive_code_challenge"].call(verifier)

  def codes = MCP::Slice["db.rom"].relations[:oauth_codes]

  def document = JSON.parse(last_response.body)

  def exchange(**overrides)
    post "/oauth/token", {
      client_id: client.client_id,
      code:,
      code_verifier: verifier,
      grant_type: "authorization_code",
      redirect_uri:,
      resource:,
    }.merge(overrides).compact
  end

  def exchange_response(**)
    exchange(**)
    last_response
  end

  def mcp_create(name, *traits, **) = Spec::DB::Factories[:mcp].create(name, *traits, **)

  def redirect_uri = client.redirect_uris.first

  def refresh(token, **overrides)
    post "/oauth/token", {
      client_id: client.client_id,
      grant_type: "refresh_token",
      refresh_token: token,
      resource:,
    }.merge(overrides).compact
  end

  def refresh_response(token, **)
    refresh(token, **)
    last_response
  end

  def refresh_token = tokens.of_type("refresh").one

  def resource = "https://aaronmallen.me/mcp"

  def revoke_client = MCP::Slice["db.rom"].relations[:oauth_clients].update(revoked_at: Time.now)

  def tokens = MCP::Slice["db.rom"].relations[:oauth_tokens]

  describe "exchanging an authorization code" do
    before { exchange }

    it "answers with JSON" do
      expect(last_response.headers["Content-Type"]).to eq("application/json")
    end

    it "keeps the answer out of caches" do
      expect(last_response.headers["Cache-Control"]).to eq("no-store")
    end

    it "hands out an access token" do
      expect(document["access_token"]).to be_a(String).and(satisfy { !it.empty? })
    end

    it "hands out a refresh token" do
      expect(document["refresh_token"]).to be_a(String).and(satisfy { !it.empty? })
    end

    it "calls the access token a bearer token" do
      expect(document["token_type"]).to eq("Bearer")
    end

    it "says the access token lasts an hour" do
      expect(document["expires_in"]).to eq(3600)
    end

    it "expires the access token after an hour" do
      expect(access_token[:expires_at]).to be_within(60).of(Time.now + 3600)
    end

    it "expires the refresh token after 30 days" do
      expect(refresh_token[:expires_at]).to be_within(60).of(Time.now + (30 * 24 * 60 * 60))
    end

    it "stores the access token hashed" do
      expect(access_token[:token_digest]).to eq(Blog::Types::SecretDigest[document.fetch("access_token")])
    end

    it "stores no plain text token" do
      expect(tokens.to_a.flat_map { it.to_h.values.map(&:to_s) }).not_to include(document.fetch("access_token"))
    end

    it "ties the tokens to the client" do
      expect(tokens.to_a.map { it[:oauth_client_id] }).to all(eq(client.id))
    end

    it "ties the tokens to the resource" do
      expect(tokens.to_a.map { it[:resource] }).to all(eq(resource))
    end

    it "ties the tokens to the scopes the code carried" do
      expect(tokens.to_a.map { it[:scopes] }).to all(eq(%w[read suggest]))
    end

    it "tells the client what the token carries" do
      expect(document["scope"]).to eq("read suggest")
    end

    it "marks the code used" do
      expect(codes.one[:used_at]).not_to be_nil
    end
  end

  describe "a code a client asked for without a redirect URI" do
    def authorization_params = super.except(:redirect_uri)

    it "grants tokens to an exchange that also leaves it out" do
      expect(exchange_response(redirect_uri: nil).status).to eq(200)
    end

    it "grants tokens to an exchange that names the URI it fell back to" do
      expect(exchange_response.status).to eq(200)
    end

    it "refuses another redirect URI" do
      exchange(redirect_uri: "https://elsewhere.example/callback")

      expect(document["error"]).to eq("invalid_grant")
    end

    it "issues no token when it refuses" do
      exchange(redirect_uri: "https://elsewhere.example/callback")

      expect(tokens.count).to eq(0)
    end
  end

  describe "a code exchange it refuses" do
    it "refuses a second exchange of the same code" do
      exchange
      exchange

      expect(last_response.status).to eq(400)
    end

    it "names the grant as the problem on a second exchange" do
      exchange
      exchange

      expect(document["error"]).to eq("invalid_grant")
    end

    it "revokes the tokens the code already bought" do
      exchange
      exchange

      expect(tokens.to_a.map { it[:revoked_at] }).to all(be_truthy)
    end

    it "refuses another PKCE verifier" do
      exchange(code_verifier: Blog::Types::NewSecret[])

      expect(document["error"]).to eq("invalid_grant")
    end

    it "refuses a missing PKCE verifier" do
      exchange(code_verifier: nil)

      expect(document["error"]).to eq("invalid_grant")
    end

    it "refuses another redirect URI" do
      exchange(redirect_uri: "https://elsewhere.example/callback")

      expect(document["error"]).to eq("invalid_grant")
    end

    it "refuses a missing redirect URI when the client sent one to be authorized" do
      exchange(redirect_uri: nil)

      expect(document["error"]).to eq("invalid_grant")
    end

    it "refuses a code it never issued" do
      exchange(code: Blog::Types::NewSecret[])

      expect(document["error"]).to eq("invalid_grant")
    end

    it "refuses a code that expired" do
      code
      codes.update(expires_at: Time.now - 1)
      exchange

      expect(document["error"]).to eq("invalid_grant")
    end

    it "refuses another client" do
      exchange(client_id: mcp_create(:oauth_client).client_id)

      expect(document["error"]).to eq("invalid_client")
    end

    it "refuses a client that was revoked" do
      code
      revoke_client
      exchange

      expect(document["error"]).to eq("invalid_client")
    end

    it "issues no token when it refuses" do
      exchange(code_verifier: Blog::Types::NewSecret[])

      expect(tokens.count).to eq(0)
    end
  end

  describe "exchanging a refresh token" do
    let(:granted) do
      exchange
      document
    end

    before { refresh(granted.fetch("refresh_token")) }

    it "hands out a new access token" do
      expect(document["access_token"]).to be_a(String).and(satisfy { it != granted["access_token"] })
    end

    it "hands out a new refresh token" do
      expect(document["refresh_token"]).to be_a(String).and(satisfy { it != granted["refresh_token"] })
    end

    it "keeps the resource" do
      expect(tokens.to_a.map { it[:resource] }).to all(eq(resource))
    end

    it "keeps the scopes" do
      expect(tokens.live.to_a.map { it[:scopes] }).to all(eq(%w[read suggest]))
    end

    it "widens no scope, whatever the client asks for" do
      refresh(document.fetch("refresh_token"), scope: "read suggest write")

      expect(document["scope"]).to eq("read suggest")
    end

    it "retires the refresh token it was given" do
      digest = Blog::Types::SecretDigest[granted.fetch("refresh_token")]

      expect(tokens.with_digest(digest).one[:revoked_at]).not_to be_nil
    end

    it "revokes the access token issued with the refresh token it was given" do
      digest = Blog::Types::SecretDigest[granted.fetch("access_token")]

      expect(tokens.with_digest(digest).one[:revoked_at]).not_to be_nil
    end

    it "leaves the access token it hands out live" do
      digest = Blog::Types::SecretDigest[document.fetch("access_token")]

      expect(tokens.with_digest(digest).one[:revoked_at]).to be_nil
    end

    it "ties the new refresh token to the new access token" do
      access = tokens.with_digest(Blog::Types::SecretDigest[document.fetch("access_token")]).one
      refresh = tokens.with_digest(Blog::Types::SecretDigest[document.fetch("refresh_token")]).one

      expect(refresh[:access_token_id]).to eq(access[:id])
    end

    it "refuses the refresh token a second time" do
      refresh(granted.fetch("refresh_token"))

      expect(document["error"]).to eq("invalid_grant")
    end

    it "revokes every token of the client when a used refresh token comes back" do
      refresh(granted.fetch("refresh_token"))

      expect(tokens.to_a.map { it[:revoked_at] }).to all(be_truthy)
    end
  end

  describe "refreshing one of two pairs a client holds" do
    let(:other) do
      exchange(code: authorization_code)
      document
    end

    def live?(token) = tokens.with_digest(Blog::Types::SecretDigest[token]).one[:revoked_at].nil?

    before do
      other
      exchange
      refresh(document.fetch("refresh_token"))
    end

    it "leaves the other access token live" do
      expect(live?(other.fetch("access_token"))).to be(true)
    end

    it "leaves the other refresh token live" do
      expect(live?(other.fetch("refresh_token"))).to be(true)
    end
  end

  describe "refreshing a pair issued before tokens were tied together" do
    let(:granted) do
      exchange
      document
    end

    before do
      granted
      tokens.update(access_token_id: nil)
      refresh(granted.fetch("refresh_token"))
    end

    it "rotates the refresh token" do
      expect(document["refresh_token"]).to be_a(String).and(satisfy { it != granted["refresh_token"] })
    end

    it "leaves the old access token to expire on its own" do
      digest = Blog::Types::SecretDigest[granted.fetch("access_token")]

      expect(tokens.with_digest(digest).one[:revoked_at]).to be_nil
    end
  end

  describe "a refresh it refuses" do
    it "refuses a refresh token it never issued" do
      refresh(Blog::Types::NewSecret[])

      expect(document["error"]).to eq("invalid_grant")
    end

    it "refuses an access token as a refresh token" do
      exchange
      refresh(document.fetch("access_token"))

      expect(document["error"]).to eq("invalid_grant")
    end

    it "refuses a refresh token that expired" do
      exchange
      token = document.fetch("refresh_token")
      tokens.of_type("refresh").update(expires_at: Time.now - 1)
      refresh(token)

      expect(document["error"]).to eq("invalid_grant")
    end

    it "refuses a client that was revoked" do
      exchange
      token = document.fetch("refresh_token")
      revoke_client
      refresh(token)

      expect(document["error"]).to eq("invalid_client")
    end

    it "refuses another client" do
      exchange
      refresh(document.fetch("refresh_token"), client_id: mcp_create(:oauth_client).client_id)

      expect(document["error"]).to eq("invalid_client")
    end
  end

  describe "two requests carrying the same code" do
    let(:code_repo) { MCP::Slice["repos.oauth_code_queries"] }

    def race
      reads = 0
      second = nil
      allow(code_repo).to(receive(:by_code).and_wrap_original do |read, value|
        read.call(value).tap { second = exchange_response if (reads += 1) == 1 }
      end)
      replace_component("repos.oauth_code_queries", code_repo)
      first = exchange_response

      [first, second]
    end

    it "grants one of them and refuses the other" do
      expect(race.map(&:status)).to contain_exactly(200, 400)
    end

    it "names the grant as the problem on the one it refuses" do
      expect(race.map { JSON.parse(it.body)["error"] }).to include("invalid_grant")
    end

    it "hands out one token pair" do
      race

      expect(tokens.to_a.map { it[:type] }).to contain_exactly("access", "refresh")
    end

    it "leaves the code burned" do
      race

      expect(codes.one[:used_at]).not_to be_nil
    end

    it "revokes the pair the code bought" do
      race

      expect(tokens.to_a.map { it[:revoked_at] }).to all(be_truthy)
    end
  end

  describe "two requests carrying the same refresh token" do
    let(:granted) do
      exchange
      document
    end
    let(:token_repo) { MCP::Slice["repos.oauth_token_queries"] }

    def race
      token = granted.fetch("refresh_token")
      reads = 0
      second = nil
      allow(token_repo).to(receive(:by_token).and_wrap_original do |read, *args, **options|
        read.call(*args, **options).tap { second = refresh_response(token) if (reads += 1) == 1 }
      end)
      replace_component("repos.oauth_token_queries", token_repo)
      first = refresh_response(token)

      [first, second]
    end

    it "rotates for one of them and refuses the other" do
      expect(race.map(&:status)).to contain_exactly(200, 400)
    end

    it "revokes every token the client holds" do
      race

      expect(tokens.to_a.map { it[:revoked_at] }).to all(be_truthy)
    end

    it "leaves no refresh token the client can spend" do
      race

      expect(tokens.of_type("refresh").live.count).to eq(0)
    end
  end

  describe "a revoke that lands during a grant", :commits do
    let(:code_repo) { MCP::Slice["repos.oauth_code_mutations"] }
    let(:token_repo) { MCP::Slice["repos.oauth_token_mutations"] }

    def database = MCP::Slice["db.rom"].gateways[:default].connection

    def revoke_after(key, repo, spend)
      revoking = nil
      allow(repo).to(receive(spend).and_wrap_original do |original, *args, **options|
        original.call(*args, **options).tap do
          revoking = Thread.new { MCP::Slice["operations.revoke_client"].call(client.id) }
          wait_until_blocked
        end
      end)
      replace_component(key, repo)
      yield
      revoking.value
    end

    def wait_until_blocked
      here = database[:pg_stat_activity].where(datname: Sequel.function(:current_database)).select(:pid)
      waiting = database[:pg_locks].where(granted: false, pid: here)
      Timeout.timeout(5) { sleep(0.01) until waiting.any? }
    end

    it "leaves no live token behind a code exchange" do
      code
      revoke_after("repos.oauth_code_mutations", code_repo, :burn) { exchange }

      expect(tokens.live.count).to eq(0)
    end

    it "leaves no live token behind a refresh" do
      exchange
      token = document.fetch("refresh_token")
      revoke_after("repos.oauth_token_mutations", token_repo, :revoke) { refresh(token) }

      expect(tokens.live.count).to eq(0)
    end
  end

  describe "a client the operator revoked" do
    before do
      exchange
      MCP::Slice["operations.revoke_client"].call(client.id)
    end

    it "connects again once the operator approves it" do
      expect(exchange_response(code: authorization_code).status).to eq(200)
    end
  end

  it "refuses a grant type it does not run" do
    post "/oauth/token", grant_type: "client_credentials"

    expect(document["error"]).to eq("unsupported_grant_type")
  end

  it "refuses a request with no grant type" do
    post "/oauth/token"

    expect(last_response.status).to eq(400)
  end

  it "answers only to POST" do
    get "/oauth/token"

    expect(last_response.status).to eq(405)
  end

  describe "a code exchange carrying a field it cannot read" do
    {
      code: ["short", "#{Blog::Types::NewSecret[]}\u0000", ""],
      code_verifier: ["short", "a" * 129, "#{'a' * 42}/", ""],
      redirect_uri: ["https://claude.ai/\u0000", ""],
    }.each do |field, values|
      values.each do |value|
        it "refuses #{value.inspect} for #{field}" do
          exchange(field => value)

          expect(document["error"]).to eq("invalid_grant")
        end
      end
    end

    { grant_type: "unsupported_grant_type", code: "invalid_grant", code_verifier: "invalid_grant",
      redirect_uri: "invalid_grant" }.each do |field, error|
      it "answers #{error} for a #{field} sent as a list" do
        exchange(field => [Blog::Types::NewSecret[]])

        expect(document["error"]).to eq(error)
      end
    end

    it "issues no token" do
      exchange(code: "short")

      expect(tokens.count).to eq(0)
    end
  end

  describe "a refresh carrying a field it cannot read" do
    before { exchange }

    ["short", "#{Blog::Types::NewSecret[]}\n", ""].each do |value|
      it "refuses #{value.inspect} for refresh_token" do
        refresh(value)

        expect(document["error"]).to eq("invalid_grant")
      end
    end

    it "refuses a refresh with no refresh_token" do
      refresh(nil)

      expect(document["error"]).to eq("invalid_grant")
    end

    it "refuses a refresh_token sent as a list" do
      refresh([document.fetch("refresh_token")])

      expect(document["error"]).to eq("invalid_grant")
    end
  end

  describe "a verifier from RFC 7636" do
    let(:verifier) { "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk" }

    def challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

    it "matches the challenge the RFC hashes it to" do
      exchange

      expect(last_response.status).to eq(200)
    end
  end

  describe "a refresh token it cannot store", :commits do
    before do
      token_repo = MCP::Slice["repos.oauth_token_mutations"]
      allow(token_repo).to receive(:issue).and_wrap_original do |issue, **attributes|
        raise Sequel::DatabaseError if attributes[:type] == Blog::Types::OAuthTokenType["refresh"]

        issue.call(**attributes)
      end
      replace_component("repos.oauth_token_mutations", token_repo)
    end

    it "stores no access token either", :aggregate_failures do
      code

      expect { exchange }.to raise_error(Sequel::DatabaseError)
      expect(tokens.count).to eq(0)
    end
  end

  describe "a replay that reaches the burn first", :commits do
    let(:code_repo) { MCP::Slice["repos.oauth_code_mutations"] }

    def blocked?
      MCP::Slice["db.rom"].gateways[:default].connection.fetch(
        "SELECT 1 FROM pg_locks WHERE NOT granted AND locktype = 'transactionid' " \
        "AND transactionid = pg_current_xact_id()::xid",
      ).any?
    end

    def exchange_fields
      { client_id: client.client_id, code:, code_verifier: verifier, grant_type: "authorization_code", redirect_uri:,
        resource: }
    end

    def race
      fields = exchange_fields
      burned = false
      replay = nil
      allow(code_repo).to receive(:burn).and_wrap_original do |burn, id|
        winner = !burned
        burned = true
        burn.call(id).tap { replay = start_replay(fields) if winner }
      end
      replace_component("repos.oauth_code_mutations", code_repo)

      [exchange_response, replay.value]
    end

    def start_replay(fields)
      Thread.new { Rack::MockRequest.new(app).post("/oauth/token", params: fields) }.tap { wait_for_the_replay(it) }
    end

    def wait_for_the_replay(replay)
      Timeout.timeout(5) { sleep(0.01) while replay.alive? && !blocked? }
    end

    it "grants one of them and refuses the other" do
      expect(race.map(&:status)).to contain_exactly(200, 400)
    end

    it "names the grant as the problem on the one it refuses" do
      expect(race.map { JSON.parse(it.body)["error"] }.compact).to eq(%w[invalid_grant])
    end

    it "revokes the pair the winner was issued" do
      race

      expect(tokens.to_a.map { it[:revoked_at] }).to contain_exactly(be_truthy, be_truthy)
    end
  end
end

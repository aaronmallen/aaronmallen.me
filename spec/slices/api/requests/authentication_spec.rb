# frozen_string_literal: true

RSpec.describe "API authentication", type: :request do
  def call_mcp(token)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{token}" }
    post "/mcp", JSON.generate(jsonrpc: "2.0", id: 1, method: "tools/list"), headers
  end

  def challenge = last_response.headers["WWW-Authenticate"]

  def document = JSON.parse(last_response.body)

  def mint(name = "Terminal") = API::Slice["operations.mint_token"].call(name:)

  def minted(name = "Terminal") = mint(name).value!

  def read_token(authorization)
    get "/api/v1/token", {}, { "HTTP_AUTHORIZATION" => authorization }.compact
  end

  def revoke(id) = API::Slice["operations.revoke_token"].call(id)

  def stored = API::Slice["db.rom"].relations[:api_tokens]

  describe "minting a token" do
    it "hands the token back" do
      expect(minted[:value]).to match(/\A[A-Za-z0-9_-]{43}\z/)
    end

    it "keeps its name" do
      expect(minted("Laptop")[:token].name).to eq("Laptop")
    end

    it "stores a digest of the token" do
      value = minted[:value]

      expect(stored.one[:token_digest]).to eq(Digest::SHA256.hexdigest(value))
    end

    it "never stores the token itself" do
      value = minted[:value]

      expect(stored.one.values).not_to include(value)
    end

    it "mints a new token each time" do
      expect(minted[:value]).not_to eq(minted[:value])
    end

    it "trims the name" do
      expect(minted("  Laptop  ")[:token].name).to eq("Laptop")
    end

    it "refuses a blank name" do
      expect(mint("   ").failure).to eq([:invalid, { name: ["blank"] }])
    end

    it "refuses a name over 100 characters" do
      expect(mint("a" * 101).failure).to eq([:invalid, { name: ["long"] }])
    end

    it "stores nothing when it refuses" do
      mint("")

      expect(stored.count).to eq(0)
    end
  end

  describe "listing tokens" do
    it "lists the live tokens, newest first" do
      first = minted("First")[:token]
      second = minted("Second")[:token]
      revoke(minted("Revoked")[:token].id)
      stored.where(id: first.id).update(created_at: Time.now - 60)

      expect(API::Slice["queries.live_tokens"].call.map(&:id)).to eq([second.id, first.id])
    end
  end

  describe "revoking a token" do
    it "stamps when it was revoked" do
      token = minted[:token]
      revoke(token.id)

      expect(stored.one[:revoked_at]).not_to be_nil
    end

    it "finds no token it never minted" do
      expect(revoke(0).failure).to eq(:not_found)
    end

    it "finds no token it already revoked" do
      token = minted[:token]
      revoke(token.id)

      expect(revoke(token.id).failure).to eq(:not_found)
    end
  end

  describe "a request with no token" do
    before { read_token(nil) }

    it "refuses it" do
      expect(last_response.status).to eq(401)
    end

    it "answers JSON" do
      expect(last_response.content_type).to start_with("application/json")
    end

    it "says what it wanted" do
      expect(document).to eq("error_description" => "this endpoint takes a bearer API token")
    end

    it "asks for a bearer token" do
      expect(challenge).to eq("Bearer")
    end
  end

  describe "a token it refuses" do
    it "refuses a token it never minted" do
      read_token("Bearer #{API::Token.generate}")

      expect(last_response.status).to eq(401)
    end

    it "names the token as the problem" do
      read_token("Bearer #{API::Token.generate}")

      expect(document).to eq("error" => "invalid_token", "error_description" => "the API token is unknown or revoked")
    end

    it "names the error in the challenge" do
      read_token("Bearer #{API::Token.generate}")

      expect(challenge).to eq(%(Bearer error="invalid_token"))
    end

    it "refuses a scheme it does not take" do
      read_token("Basic #{minted[:value]}")

      expect(last_response.status).to eq(401)
    end

    it "refuses a revoked token" do
      value, token = minted.values_at(:value, :token)
      revoke(token.id)
      read_token("Bearer #{value}")

      expect(last_response.status).to eq(401)
    end

    it "answers a revoked token with JSON" do
      value, token = minted.values_at(:value, :token)
      revoke(token.id)
      read_token("Bearer #{value}")

      expect(document["error"]).to eq("invalid_token")
    end

    it "refuses an MCP access token" do
      access_token = mcp_connect(
        Spec::DB::Factories[:mcp].create(:oauth_client), verifier: MCP::OAuth::Secret.generate, scope: "read write",
      ).fetch("access_token")
      read_token("Bearer #{access_token}")

      expect(last_response.status).to eq(401)
    end
  end

  describe "a request with a valid token" do
    let(:value) { minted("Laptop")[:value] }

    it "reaches the slice" do
      read_token("Bearer #{value}")

      expect(last_response.status).to eq(200)
    end

    it "takes the scheme in any case" do
      read_token("bearer #{value}")

      expect(last_response.status).to eq(200)
    end

    it "names the token it carried" do
      read_token("Bearer #{value}")

      expect(document["name"]).to eq("Laptop")
    end

    it "stamps the token's last use" do
      value
      before = Time.now
      read_token("Bearer #{value}")

      expect(stored.one[:last_used_at]).to be >= before.floor
    end

    it "answers with the last use it stamped" do
      read_token("Bearer #{value}")

      expect(document["last_used_at"]).to eq(stored.one[:last_used_at].utc.iso8601)
    end

    it "tells every cache not to store the answer" do
      read_token("Bearer #{value}")

      expect(last_response.headers["Cache-Control"]).to eq("private, no-store")
    end

    it "gets no way into MCP" do
      call_mcp(value)

      expect(last_response.status).to eq(401)
    end
  end
end

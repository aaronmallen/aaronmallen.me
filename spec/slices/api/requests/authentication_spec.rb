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
      read_token("Bearer #{Blog::Types::NewSecret[]}")

      expect(last_response.status).to eq(401)
    end

    it "names the token as the problem" do
      read_token("Bearer #{Blog::Types::NewSecret[]}")

      expect(document).to eq("error" => "invalid_token", "error_description" => "the API token is unknown or revoked")
    end

    it "names the error in the challenge" do
      read_token("Bearer #{Blog::Types::NewSecret[]}")

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
        Spec::DB::Factories[:mcp].create(:oauth_client), verifier: Blog::Types::NewSecret[], scope: "read write",
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

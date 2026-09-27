# frozen_string_literal: true

RSpec.describe "OAuth discovery metadata", type: :request do
  let(:issuer) { "https://aaronmallen.me" }

  def document = JSON.parse(last_response.body)

  describe "the protected resource metadata" do
    before { get "/.well-known/oauth-protected-resource/mcp" }

    it "answers" do
      expect(last_response.status).to eq(200)
    end

    it "answers with JSON" do
      expect(last_response.headers["Content-Type"]).to eq("application/json")
    end

    it "allows a browser client to read it" do
      expect(last_response.headers["Access-Control-Allow-Origin"]).to eq("*")
    end

    it "names the MCP endpoint as the resource" do
      expect(document["resource"]).to eq("#{issuer}/mcp")
    end

    it "points at this server as the authorization server" do
      expect(document["authorization_servers"]).to eq([issuer])
    end

    it "takes the token from the Authorization header" do
      expect(document["bearer_methods_supported"]).to eq(%w[header])
    end

    it "names the resource" do
      expect(document["resource_name"]).to eq("aaronmallen.me")
    end
  end

  it "names the same scopes in both documents" do
    get "/.well-known/oauth-authorization-server"
    offered = document["scopes_supported"]
    get "/.well-known/oauth-protected-resource/mcp"

    expect(document["scopes_supported"]).to eq(offered)
  end

  it "serves the same document at the root well-known path" do
    get "/.well-known/oauth-protected-resource"
    root = document
    get "/.well-known/oauth-protected-resource/mcp"

    expect(root).to eq(document)
  end

  describe "the authorization server metadata" do
    before { get "/.well-known/oauth-authorization-server" }

    it "answers" do
      expect(last_response.status).to eq(200)
    end

    it "answers with JSON" do
      expect(last_response.headers["Content-Type"]).to eq("application/json")
    end

    it "allows a browser client to read it" do
      expect(last_response.headers["Access-Control-Allow-Origin"]).to eq("*")
    end

    it "names itself as the issuer" do
      expect(document["issuer"]).to eq(issuer)
    end

    it "describes the endpoints" do
      expect(document).to include(
        "authorization_endpoint" => "#{issuer}/oauth/authorize",
        "registration_endpoint" => "#{issuer}/oauth/register",
        "token_endpoint" => "#{issuer}/oauth/token",
      )
    end

    it "supports the authorization code and refresh token grants" do
      expect(document["grant_types_supported"]).to eq(%w[authorization_code refresh_token])
    end

    it "names the scopes a client can ask for" do
      expect(document["scopes_supported"]).to eq(%w[read suggest write])
    end

    it "asks for PKCE with S256" do
      expect(document["code_challenge_methods_supported"]).to eq(%w[S256])
    end

    it "takes public clients only" do
      expect(document["token_endpoint_auth_methods_supported"]).to eq(%w[none])
    end

    it "answers the authorization request with its issuer" do
      expect(document["authorization_response_iss_parameter_supported"]).to be(true)
    end

    it "gives a registration endpoint that registers" do
      registration = { redirect_uris: %w[https://claude.ai/api/mcp/auth_callback] }.to_json
      post document.fetch("registration_endpoint"), registration

      expect(last_response.status).to eq(201)
    end
  end

  describe "a request whose Host somebody else picked" do
    def forwarded(path) = get(path, {}, "HTTP_X_FORWARDED_HOST" => "evil.example")

    it "names the configured issuer and endpoints all the same" do
      forwarded("/.well-known/oauth-authorization-server")

      expect(document.values_at("issuer", "authorization_endpoint", "registration_endpoint", "token_endpoint"))
        .to eq([issuer, "#{issuer}/oauth/authorize", "#{issuer}/oauth/register", "#{issuer}/oauth/token"])
    end

    it "names the configured resource all the same" do
      forwarded("/.well-known/oauth-protected-resource/mcp")

      expect(document.values_at("resource", "resource_name", "authorization_servers"))
        .to eq(["#{issuer}/mcp", "aaronmallen.me", [issuer]])
    end
  end

  it "leaves the rest of the site to the app" do
    get "/writing"

    expect(last_response.status).to eq(200)
  end

  it "still answers unknown paths with a 404" do
    get "/nothing-here"

    expect(last_response.status).to eq(404)
  end
end

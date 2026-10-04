# frozen_string_literal: true

RSpec.describe "OAuth discovery metadata", type: :request do
  let(:issuer) { "https://aaronmallen.me" }

  def authorization_server
    {
      "authorization_endpoint" => "#{issuer}/oauth/authorize",
      "authorization_response_iss_parameter_supported" => true,
      "code_challenge_methods_supported" => %w[S256],
      "grant_types_supported" => %w[authorization_code refresh_token],
      "issuer" => issuer,
      "registration_endpoint" => "#{issuer}/oauth/register",
      "scopes_supported" => %w[read suggest write],
      "token_endpoint" => "#{issuer}/oauth/token",
      "token_endpoint_auth_methods_supported" => %w[none],
    }
  end

  def document = JSON.parse(last_response.body)

  def protected_resource
    {
      "authorization_servers" => [issuer],
      "bearer_methods_supported" => %w[header],
      "resource" => "#{issuer}/mcp",
      "resource_name" => "aaronmallen.me",
    }
  end

  def served
    headers = shared_headers.keys.to_h { [it, last_response.headers[it]] }

    { status: last_response.status, headers:, document: }
  end

  def shared_headers = { "Access-Control-Allow-Origin" => "*", "Content-Type" => "application/json" }

  it "serves the protected resource metadata" do
    get "/.well-known/oauth-protected-resource/mcp"

    expect(served).to match(status: 200, headers: shared_headers, document: include(protected_resource))
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

    it "serves the metadata" do
      expect(served).to match(status: 200, headers: shared_headers, document: include(authorization_server))
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

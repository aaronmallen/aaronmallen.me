# frozen_string_literal: true

RSpec.describe "MCP connection tools", type: :request do
  def access_token
    @access_token ||= connect(calling_client, scope: "read").fetch("access_token")
  end

  def call_tool(name)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}" }
    post "/mcp", JSON.generate(jsonrpc: "2.0", id: 1, method: "tools/call", params: { name:, arguments: {} }), headers
  end

  def calling_client = @calling_client ||= mcp_create(:oauth_client, client_name: "Claude")

  def connect(client, scope:) = mcp_connect(client, verifier: Blog::Types::NewSecret[], scope:)

  def content = JSON.parse(message)

  def document = JSON.parse(last_response.body)

  def marked(text) = { "untrusted" => true, "text" => text }

  def mcp_create(name, *traits, **) = Spec::DB::Factories[:mcp].create(name, *traits, **)

  def message = document.dig("result", "content").first.fetch("text")

  def mint(name) = API::Slice["operations.mint_token"].call(name:).value!

  def tokens = API::Slice["db.rom"].relations[:api_tokens]

  describe "list_api_tokens" do
    def entry(token, created_at, last_used_at = nil)
      { "id" => token.id, "name" => token.name, "created_at" => created_at, "last_used_at" => last_used_at }
    end

    def minted_at(name, created_at, last_used_at = nil)
      mint(name).fetch(:token).tap { tokens.by_pk(it.id).update(created_at:, last_used_at:) }
    end

    it "answers each live token's id, name and times, newest first" do
      older = minted_at("Laptop", Time.utc(2026, 9, 1), Time.utc(2026, 9, 2))
      newer = minted_at("Terminal", Time.utc(2026, 9, 3))
      call_tool("list_api_tokens")

      expect(content.fetch("tokens"))
        .to eq([entry(newer, "2026-09-03T00:00:00Z"), entry(older, "2026-09-01T00:00:00Z", "2026-09-02T00:00:00Z")])
    end

    it "leaves out a revoked token" do
      kept = mint("Laptop").fetch(:token)
      API::Slice["operations.revoke_token"].call(mint("Old").fetch(:token).id)
      call_tool("list_api_tokens")

      expect(content.fetch("tokens").map { it.fetch("id") }).to eq([kept.id])
    end

    it "never sends a token or its digest" do
      minted = mint("Laptop")
      call_tool("list_api_tokens")

      expect(message).not_to include(minted.fetch(:value), minted.fetch(:token).token_digest)
    end
  end

  describe "list_clients" do
    def clients = content.fetch("clients")

    def connected(scope: "read", **) = mcp_create(:oauth_client, **).tap { connect(it, scope:) }

    def entry(client, name, scopes)
      {
        "id" => client.id, "name" => marked(name), "scopes" => scopes, "created_at" => client.created_at.utc.iso8601,
        "last_used_at" => nil, "current" => false,
      }
    end

    def listed(client) = clients.find { it.fetch("id") == client.id }

    it "answers each connected client's id, name, granted scopes and times" do
      other = connected(client_name: "Cursor", scope: "write read")
      call_tool("list_clients")

      expect(listed(other)).to eq(entry(other, "Cursor", %w[read write]))
    end

    it "marks the calling client as current, with the time it last used the server" do
      call_tool("list_clients")

      expect(listed(calling_client)).to include("current" => true, "scopes" => %w[read])
        .and include("last_used_at" => a_string_matching(/\A\d{4}-\d\d-\d\dT/))
    end

    it "names a client with no registered name by its redirect host" do
      other = connected(client_name: nil, redirect_uris: %w[https://cursor.example/callback])
      call_tool("list_clients")

      expect(listed(other).fetch("name")).to eq(marked("cursor.example"))
    end

    it "leaves out a revoked client and one holding no live token" do
      MCP::Slice["operations.revoke_client"].call(connected.id)
      mcp_create(:oauth_client)
      call_tool("list_clients")

      expect(clients.map { it.fetch("id") }).to eq([calling_client.id])
    end

    it "never sends a token or its digest" do
      call_tool("list_clients")

      expect(message).not_to include(access_token, Blog::Types::SecretDigest[access_token])
    end
  end
end

# frozen_string_literal: true

RSpec.describe "MCP connection tools", type: :request do
  def connect(client, scope:) = mcp_connect(client, verifier: Blog::Types::NewSecret[], scope:)

  def mcp_scopes = %w[read]

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
      mcp_call("list_api_tokens")

      expect(mcp_content.fetch("tokens"))
        .to eq([entry(newer, "2026-09-03T00:00:00Z"), entry(older, "2026-09-01T00:00:00Z", "2026-09-02T00:00:00Z")])
    end

    it "leaves out a revoked token" do
      kept = mint("Laptop").fetch(:token)
      API::Slice["operations.revoke_token"].call(mint("Old").fetch(:token).id)
      mcp_call("list_api_tokens")

      expect(mcp_content.fetch("tokens").map { it.fetch("id") }).to eq([kept.id])
    end

    it "never sends a token or its digest" do
      minted = mint("Laptop")
      mcp_call("list_api_tokens")

      expect(mcp_message).not_to include(minted.fetch(:value), minted.fetch(:token).token_digest)
    end
  end

  describe "list_clients" do
    def clients = mcp_content.fetch("clients")

    def connected(scope: "read", **) = create(:oauth_client, **).tap { connect(it, scope:) }

    def entry(client, name, scopes)
      {
        "id" => client.id, "name" => marked(name), "scopes" => scopes, "created_at" => client.created_at.utc.iso8601,
        "last_used_at" => nil, "current" => false,
      }
    end

    def listed(client) = clients.find { it.fetch("id") == client.id }

    it "answers each connected client's id, name, granted scopes and times" do
      other = connected(client_name: "Cursor", scope: "write read")
      mcp_call("list_clients")

      expect(listed(other)).to eq(entry(other, "Cursor", %w[read write]))
    end

    it "marks the calling client as current, with the time it last used the server" do
      mcp_call("list_clients")

      expect(listed(mcp_client)).to include("current" => true, "scopes" => %w[read])
        .and include("last_used_at" => a_string_matching(/\A\d{4}-\d\d-\d\dT/))
    end

    it "names a client with no registered name by its redirect host" do
      other = connected(client_name: nil, redirect_uris: %w[https://cursor.example/callback])
      mcp_call("list_clients")

      expect(listed(other).fetch("name")).to eq(marked("cursor.example"))
    end

    it "leaves out a revoked client and one holding no live token" do
      MCP::Slice["operations.revoke_client"].call(connected.id)
      create(:oauth_client)
      mcp_call("list_clients")

      expect(clients.map { it.fetch("id") }).to eq([mcp_client.id])
    end

    it "never sends a token or its digest" do
      mcp_call("list_clients")

      expect(mcp_message).not_to include(mcp_access_token, Blog::Types::SecretDigest[mcp_access_token])
    end
  end
end

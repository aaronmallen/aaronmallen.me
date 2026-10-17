# frozen_string_literal: true

RSpec.describe "API MCP clients", type: :request do
  def connect(client, scope:)
    MCP::Slice["operations.issue_tokens"].call(
      oauth_client_id: client.id,
      resource: MCP::Slice["operations.describe_protected_resource"].call(Hanami.app.settings.site_url.chomp("/"))[:resource],
      scopes: scope.split,
    )
  end

  def connected(scope: "read", **) = create(:oauth_client, **).tap { connect(it, scope:) }

  def list
    get "/api/v1/clients", nil, { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    JSON.parse(last_response.body).fetch("clients")
  end

  it "lists each connected client with its name, granted scopes and times" do
    client = connected(client_name: "Cursor", scope: "write read")

    expect([list, last_response.status]).to eq(
      [[{ "id" => client.id, "name" => "Cursor", "scopes" => %w[read write],
          "created_at" => client.created_at.utc.iso8601, "last_used_at" => nil }], 200],
    )
  end

  it "names a client with no registered name by its redirect host" do
    connected(client_name: nil, redirect_uris: %w[https://cursor.example/callback])

    expect(list.map { it.fetch("name") }).to eq(%w[cursor.example])
  end

  it "leaves out a revoked client and one holding no live token" do
    MCP::Slice["operations.revoke_client"].call(connected.id)
    create(:oauth_client)

    expect(list).to be_empty
  end
end

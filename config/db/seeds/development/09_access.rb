# frozen_string_literal: true

Admin::Slice["repos.owner_identity_mutations"].add_github(931_094)

api = API::Slice

if api["repos.api_token_queries"].live.empty?
  Seeds.unwrap(api["operations.mint_token"].call({ name: "Shortcuts on my phone" }))
  retired = Seeds.unwrap(api["operations.mint_token"].call({ name: "Old laptop" }))
  Seeds.unwrap(api["operations.revoke_token"].call(retired[:token].id))
end

if MCP::Slice["repos.oauth_client_queries"].connected.empty?
  client = Seeds.unwrap(
    MCP::Slice["operations.register_client"].call(
      { "redirect_uris" => ["http://127.0.0.1:33418/callback"], "client_name" => "Example Desktop" },
      visitor_hash: Analytics::Slice["operations.hash_visitor"].call(address: "192.0.2.30"),
    ),
  )
  registered = MCP::Slice["repos.oauth_client_queries"].connected_by_client_id(client[:client_id])

  Seeds.unwrap(
    MCP::Slice["operations.issue_tokens"].call(
      oauth_client_id: registered.id, resource: Hanami.app.settings.site_url("/mcp"), scopes: %w[read write],
    ),
  )
end

# frozen_string_literal: true

module MCPConnect
  def mcp_authorization_code(client, verifier:, scope: nil)
    params = {
      client_id: client.client_id,
      code_challenge: MCP::Slice["operations.derive_code_challenge"].call(verifier),
      code_challenge_method: Blog::Types::CodeChallengeMethod["S256"],
      redirect_uri: client.redirect_uris.first,
      response_type: "code",
      scope:,
    }.compact
    sign_in_to_admin
    approve_authorization("#{MCPAuthorize::AUTHORIZE_PATH}?#{Rack::Utils.build_query(params)}")
    Rack::Utils.parse_query(URI(last_response.location).query).fetch("code")
  end

  def mcp_connect(client, verifier:, scope: nil)
    mcp_exchange(client, mcp_authorization_code(client, verifier:, scope:), verifier:)
  end

  def mcp_exchange(client, code, verifier:)
    post "/oauth/token", {
      client_id: client.client_id,
      code:,
      code_verifier: verifier,
      grant_type: "authorization_code",
      redirect_uri: client.redirect_uris.first,
    }
    JSON.parse(last_response.body)
  end

  def mcp_refresh(client, refresh_token)
    post "/oauth/token", { client_id: client.client_id, grant_type: "refresh_token", refresh_token: }
    JSON.parse(last_response.body)
  end
end

RSpec.configure do |config|
  config.include MCPConnect, type: :request
end

# frozen_string_literal: true

module MCPToolCalls
  SCOPES = "read suggest write"

  def mcp_answer(name, **) = JSON.parse(mcp_text(name, **))

  def mcp_call(name, **arguments)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{mcp_access_token}" }
    post "/mcp", JSON.generate(jsonrpc: "2.0", id: 1, method: "tools/call", params: { name:, arguments: }), headers
    JSON.parse(last_response.body).fetch("result")
  end

  def mcp_text(name, **) = mcp_call(name, **).fetch("content").first.fetch("text")

  private

  def mcp_access_token
    @mcp_access_token ||= mcp_connect(
      Spec::DB::Factories[:mcp].create(:oauth_client), verifier: MCP::OAuth::Secret.generate, scope: SCOPES,
    ).fetch("access_token")
  end
end

RSpec.configure do |config|
  config.include MCPToolCalls, type: :request
end

# frozen_string_literal: true

module MCPToolCalls
  SCOPES = "read suggest write publish delete mail"

  def marked(text) = { "untrusted" => true, "text" => text }

  def mcp_answer(name, **) = JSON.parse(mcp_text(name, **))

  def mcp_call(name, **arguments)
    mcp_rpc("tools/call", { name:, arguments: })
    mcp_reply["result"]
  end

  def mcp_content = JSON.parse(mcp_message)

  def mcp_message = mcp_result.fetch("content").first.fetch("text")

  def mcp_refused? = mcp_result.fetch("isError", false)

  def mcp_reply = JSON.parse(last_response.body)

  def mcp_result = mcp_reply.fetch("result")

  def mcp_rpc(method, params = nil, id: 1, authorization: "Bearer #{mcp_access_token}", headers: {})
    sent = { "CONTENT_TYPE" => "application/json", **headers }
    sent["HTTP_AUTHORIZATION"] = authorization if authorization
    post "/mcp", JSON.generate({ jsonrpc: "2.0", id:, method:, params: }.compact), sent
  end

  def mcp_text(name, **)
    mcp_call(name, **)
    mcp_message
  end

  def trusted(value)
    case value
      when Hash then value["untrusted"] == true ? value["text"] : value.transform_values { trusted(it) }
      when Array then value.map { trusted(it) }
      else value
    end
  end

  def unstamped(value)
    case value
      when Hash then value.except("updated_at").transform_values { unstamped(it) }
      when Array then value.map { unstamped(it) }
      else value
    end
  end

  private

  def mcp_access_token
    @mcp_access_token ||= MCP::Slice["operations.issue_tokens"].call(
      oauth_client_id: mcp_client.id,
      resource: MCP::Slice["operations.describe_protected_resource"].call(Hanami.app.settings.site_url.chomp("/"))[:resource],
      scopes: mcp_scopes,
    ).fetch(:access_token)
  end

  def mcp_client = @mcp_client ||= create(:oauth_client)

  def mcp_scopes = SCOPES.split
end

RSpec.configure do |config|
  config.include MCPToolCalls, type: :request
end

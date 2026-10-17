# frozen_string_literal: true

RSpec.describe "MCP tool descriptions", type: :request do
  def descriptions
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{mcp_access_token}" }
    post "/mcp", JSON.generate(jsonrpc: "2.0", id: 1, method: "tools/list"), headers
    JSON.parse(last_response.body).dig("result", "tools").to_h { it.values_at("name", "description") }
  end

  it "states the open range in the same words" do
    expect(descriptions.values_at("list_mail_threads", "list_social_posts", "list_webmentions"))
      .to all(include(API::Helpers::DayWindow::OPEN_NOTE))
  end

  it "states the capped range in the same words" do
    expect(descriptions.values_at("read_analytics", "summarize_activity"))
      .to all(include(API::Helpers::DayWindow::CAPPED_NOTE))
  end

  it "states the untrusted text of webmentions and deliveries in the same words" do
    expect(descriptions.values_at("list_webmentions", "read_webmention", "read_social_post"))
      .to contain_exactly(include(MCP::Tools::Untrusted::WEBMENTIONS), include(MCP::Tools::Untrusted::WEBMENTIONS),
                          include(MCP::Tools::Untrusted::DELIVERY))
  end

  it "names the photo size limit the contract checks" do
    limit = Blog::Helpers::Figures.size(Media::Contracts::PhotoContract::MAX_BYTES)

    expect(descriptions.fetch("upload_photo")).to end_with("up to #{limit}")
  end
end

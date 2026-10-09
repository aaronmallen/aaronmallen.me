# frozen_string_literal: true

RSpec.describe "Robots", type: :request do
  def lines = last_response.body.lines(chomp: true)

  def rules = ["User-agent: *", *%w[/admin /api /mcp /oauth /pulse /webmention].map { "Disallow: #{it}" }, "Allow: /"]

  it "answers as plain text" do
    get "/robots.txt"

    expect(last_response.media_type).to eq("text/plain")
  end

  it "answers a crawler that takes anything" do
    get "/robots.txt", {}, "HTTP_ACCEPT" => "*/*"

    expect(last_response.media_type).to eq("text/plain")
  end

  it "keeps every crawler off the private paths and allows the rest" do
    get "/robots.txt"

    expect(lines).to start_with(*rules)
  end

  it "names the sitemap" do
    get "/robots.txt"

    expect(lines).to include("Sitemap: https://aaronmallen.me/sitemap.xml")
  end
end

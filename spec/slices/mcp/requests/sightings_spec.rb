# frozen_string_literal: true

RSpec.describe "MCP client sightings", type: :request do
  let(:agent) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36" }
  let(:client) { create(:oauth_client) }
  let(:sightings) { Security::Slice["db.rom"].gateways[:default].connection[:sightings] }
  let(:value) { Blog::Types::NewSecret[] }

  before do
    use_country_database
    write_country_database
    allow(Hanami.app.settings).to receive(:proxy)
      .and_return(address_header: "CF-Connecting-IP", trusted_proxies: [IPAddr.new("127.0.0.0/8")])
    resource = "#{Hanami.app.settings.site_url.chomp('/')}/mcp"
    create(:oauth_token, oauth_client: client, token_digest: Blog::Types::SecretDigest[value], resource:)
  end

  def call_mcp(address: "81.2.69.160", user_agent: agent, token: value)
    post "/mcp", JSON.generate(jsonrpc: "2.0", id: 1, method: "tools/list"), {
      "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{token}",
      "HTTP_CF_CONNECTING_IP" => address, "HTTP_USER_AGENT" => user_agent,
    }
  end

  def recorded
    {
      api_token_id: nil, oauth_client_id: client.id, browser: "Chrome", os: "macOS", city: "London", country: "GB",
      country_name: "United Kingdom", calls: 1,
    }
  end

  it "records where the client called from" do
    call_mcp

    expect(sightings.select(*recorded.keys).all).to eq([recorded])
  end

  it "keeps the last address, user agent and time" do
    call_mcp

    expect(sightings.select(:last_address, :last_user_agent, :first_seen_at, :last_seen_at).first).to match(
      last_address: "81.2.69.160", last_user_agent: agent, first_seen_at: be_within(5).of(Time.now),
      last_seen_at: be_within(5).of(Time.now),
    )
  end

  it "counts a repeat call from the same device and city on one row" do
    3.times { call_mcp }

    expect(sightings.select_map(:calls)).to eq([3])
  end

  it "adds a row for another city" do
    call_mcp
    call_mcp(address: "198.51.100.7")

    expect(sightings.order(:id).select_map(:city)).to eq(%w[London Nowhere])
  end

  it "records nothing for a token it refuses" do
    call_mcp(token: Blog::Types::NewSecret[])

    expect(sightings.count).to eq(0)
  end

  describe "a client deleted after it authenticates", :commits do
    before do
      authenticate = MCP::Slice["operations.authenticate"]
      allow(authenticate).to(receive(:call).and_wrap_original do |read, *args, **options|
        read.call(*args, **options).tap { MCP::Slice["db.rom"].gateways[:default].connection[:oauth_clients].delete }
      end)
      replace_component("operations.authenticate", authenticate)
    end

    it "answers 401" do
      call_mcp

      expect([last_response.status, JSON.parse(last_response.body)["error"]]).to eq([401, "invalid_token"])
    end

    it "records nothing" do
      call_mcp

      expect(sightings.count).to eq(0)
    end
  end
end

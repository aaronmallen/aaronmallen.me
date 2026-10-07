# frozen_string_literal: true

RSpec.describe "API token sightings", type: :request do
  let(:agent) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36" }
  let(:minted) { API::Slice["operations.mint_token"].call(name: "Terminal").value! }
  let(:sightings) { Security::Slice["db.rom"].gateways[:default].connection[:sightings] }

  before do
    use_country_database
    write_country_database
    allow(Hanami.app.settings).to receive(:proxy)
      .and_return(address_header: "CF-Connecting-IP", trusted_proxies: [IPAddr.new("127.0.0.0/8")])
  end

  def call_api(address: "81.2.69.160", user_agent: agent, token: minted[:value])
    get "/api/v1/token", {}, {
      "HTTP_AUTHORIZATION" => "Bearer #{token}", "HTTP_CF_CONNECTING_IP" => address, "HTTP_USER_AGENT" => user_agent,
    }
  end

  def recorded
    {
      api_token_id: token_id, oauth_client_id: nil, browser: "Chrome", os: "macOS", city: "London", country: "GB",
      calls: 1,
    }
  end

  def token_id = minted[:token].id

  it "records where the token called from" do
    call_api

    expect(sightings.select(*recorded.keys).all).to eq([recorded])
  end

  it "keeps the last address and user agent" do
    call_api

    expect(sightings.select(:last_address, :last_user_agent).first)
      .to eq(last_address: "81.2.69.160", last_user_agent: agent)
  end

  it "stamps when it first and last saw the token" do
    call_api

    expect(sightings.select(:first_seen_at, :last_seen_at).first.values).to all(be_within(5).of(Time.now))
  end

  it "counts a repeat call from the same device and city on one row" do
    3.times { call_api(user_agent: "#{agent} build/#{it}") }

    expect(sightings.select(:calls, :last_user_agent).all).to eq([{ calls: 3, last_user_agent: "#{agent} build/2" }])
  end

  it "keeps the first sighting's time when the token calls again" do
    call_api
    sightings.update(first_seen_at: Time.now - 3600, last_seen_at: Time.now - 3600)
    call_api

    expect(sightings.select(:first_seen_at, :last_seen_at).first)
      .to match(first_seen_at: be_within(5).of(Time.now - 3600), last_seen_at: be_within(5).of(Time.now))
  end

  it "adds a row for another city" do
    call_api
    call_api(address: "198.51.100.7")

    expect(sightings.order(:id).select_map(:city)).to eq(%w[London Nowhere])
  end

  it "adds a row for another device" do
    call_api
    call_api(user_agent: "curl/8.7.1")

    expect(sightings.order(:id).select_map(%i[browser os])).to eq([%w[Chrome macOS], [nil, nil]])
  end

  it "counts calls from a device it can't read on one row" do
    2.times { call_api(user_agent: "curl/8.7.1") }

    expect(sightings.select_map(:calls)).to eq([2])
  end

  it "records nothing for a token it refuses" do
    call_api(token: Blog::SecretToken.generate)

    expect(sightings.count).to eq(0)
  end
end

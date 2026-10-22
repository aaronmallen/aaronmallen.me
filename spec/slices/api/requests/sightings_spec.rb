# frozen_string_literal: true

RSpec.describe "API token sightings", type: :request do
  let(:agent) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36" }
  let(:minted) { API::Slice["operations.mint_token"].call(name: "Terminal").value! }
  let(:known_devices) { Security::Slice["db.rom"].gateways[:default].connection[:known_devices] }
  let(:sightings) { Security::Slice["db.rom"].gateways[:default].connection[:sightings] }

  before do
    use_country_database
    write_country_database
    allow(Hanami.app.settings).to receive(:proxy)
      .and_return(address_header: "CF-Connecting-IP", trusted_proxies: [IPAddr.new("127.0.0.0/8")])
  end

  def check_in(address: "81.2.69.160", user_agent: agent, token: minted[:value])
    get "/api/v1/token", {}, {
      "HTTP_AUTHORIZATION" => "Bearer #{token}", "HTTP_CF_CONNECTING_IP" => address, "HTTP_USER_AGENT" => user_agent,
    }
  end

  def recorded
    {
      api_token_id: token_id, oauth_client_id: nil, browser: "Chrome", os: "macOS", city: "London", country: "GB",
      country_name: "United Kingdom", calls: 1,
    }
  end

  def token_id = minted[:token].id

  it "records where the token called from" do
    check_in

    expect(sightings.select(*recorded.keys).all).to eq([recorded])
  end

  it "keeps the last address and user agent" do
    check_in

    expect(sightings.select(:last_address, :last_user_agent).first)
      .to eq(last_address: "81.2.69.160", last_user_agent: agent)
  end

  it "stamps when it first and last saw the token" do
    check_in

    expect(sightings.select(:first_seen_at, :last_seen_at).first.values).to all(be_within(5).of(Time.now))
  end

  it "counts a repeat call from the same device and city on one row" do
    3.times { check_in(user_agent: "#{agent} build/#{it}") }

    expect(sightings.select(:calls, :last_user_agent).all).to eq([{ calls: 3, last_user_agent: "#{agent} build/2" }])
  end

  it "keeps the first sighting's time when the token calls again" do
    check_in
    sightings.update(first_seen_at: Time.now - 3600, last_seen_at: Time.now - 3600)
    check_in

    expect(sightings.select(:first_seen_at, :last_seen_at).first)
      .to match(first_seen_at: be_within(5).of(Time.now - 3600), last_seen_at: be_within(5).of(Time.now))
  end

  it "keeps one row with the latest city and address when the token calls from another city" do
    check_in
    check_in(address: "198.51.100.7")

    expect(sightings.select(:city, :last_address, :calls).all)
      .to eq([{ city: "Nowhere", last_address: "198.51.100.7", calls: 2 }])
  end

  it "adds a row for another device" do
    check_in
    check_in(user_agent: "curl/8.7.1")

    expect(sightings.order(:id).select_map(%i[browser os])).to eq([%w[Chrome macOS], [nil, nil]])
  end

  it "counts calls from a device it can't read on one row" do
    2.times { check_in(user_agent: "curl/8.7.1") }

    expect(sightings.select_map(:calls)).to eq([2])
  end

  it "knows the device it saw" do
    check_in

    device = recorded.except(:calls)

    expect(known_devices.select(*device.keys).all).to eq([device])
  end

  it "knows a device once however often it calls" do
    3.times { check_in }

    expect(known_devices.count).to eq(1)
  end

  it "records a sighting in one statement" do
    minted
    found = counting { check_in }

    expect(found.grep(/known_devices|sightings/).size).to eq(1)
  end

  it "records nothing for a token it refuses" do
    check_in(token: Blog::Types::NewSecret[])

    expect(sightings.count).to eq(0)
  end

  describe "a token deleted after it authenticates", :commits do
    before do
      authenticate = API::Slice["operations.authenticate"]
      allow(authenticate).to(receive(:call).and_wrap_original do |read, *args|
        read.call(*args).tap { API::Slice["db.rom"].gateways[:default].connection[:api_tokens].delete }
      end)
      replace_component("operations.authenticate", authenticate)
    end

    it "answers 401" do
      check_in

      expect([last_response.status, JSON.parse(last_response.body)["error"]]).to eq([401, "invalid_token"])
    end

    it "records nothing" do
      check_in

      expect([sightings.count, known_devices.count]).to eq([0, 0])
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Visitor address", type: :request do
  let(:agent) { "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36" }
  let(:client) { "203.0.113.7" }
  let(:countries) { Analytics::Slice["geo.countries"] }
  let(:looked_up) { [] }
  let(:proxy) { "127.0.0.1" }

  before do
    allow(countries).to receive(:place) do |address|
      looked_up << address
      Analytics::Structs::Place.new(city: nil, country: nil, country_name: nil)
    end
  end

  def address(**headers)
    post(
      "/pulse",
      { kind: "view", path: "/about", title: "About" }.to_json,
      "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => agent, "REMOTE_ADDR" => proxy, **headers,
    )
    looked_up.last
  end

  def behind(header, trusted: %w[127.0.0.0/8])
    allow(Hanami.app.settings).to receive(:proxy)
      .and_return(address_header: header, trusted_proxies: trusted.map { IPAddr.new(it) })
  end

  context "with no header named" do
    before { behind(nil) }

    it "takes the address the connection came from" do
      expect(address).to eq(proxy)
    end

    it "ignores an address the client asked for" do
      expect(address("HTTP_X_FORWARDED_FOR" => client)).to eq(proxy)
    end
  end

  context "with the proxy's header named" do
    before { behind("CF-Connecting-IP") }

    it "takes the address the proxy wrote" do
      expect(address("HTTP_CF_CONNECTING_IP" => client)).to eq(client)
    end

    it "ignores every other header the client sets" do
      expect(address("HTTP_X_FORWARDED_FOR" => "198.51.100.4", "HTTP_X_REAL_IP" => "198.51.100.5")).to eq(proxy)
    end

    it "falls back to the connection when the proxy wrote nothing" do
      expect(address).to eq(proxy)
    end

    it "falls back to the connection when the header is blank" do
      expect(address("HTTP_CF_CONNECTING_IP" => "  ")).to eq(proxy)
    end

    it "takes the nearest address when the header carries a list" do
      expect(address("HTTP_CF_CONNECTING_IP" => "198.51.100.4, #{client}")).to eq(client)
    end
  end

  context "with a header named in lower case" do
    before { behind("cf-connecting-ip") }

    it "reads the same header" do
      expect(address("HTTP_CF_CONNECTING_IP" => client)).to eq(client)
    end
  end

  context "with the connection outside every trusted range" do
    let(:proxy) { "198.51.100.9" }

    before { behind("CF-Connecting-IP") }

    it "ignores the header a sender forged" do
      expect(address("HTTP_CF_CONNECTING_IP" => client)).to eq(proxy)
    end
  end

  context "with no proxy trusted" do
    before { behind("CF-Connecting-IP", trusted: []) }

    it "ignores the header, since an unnamed proxy is no proxy" do
      expect(address("HTTP_CF_CONNECTING_IP" => client)).to eq(proxy)
    end
  end

  context "with a range that holds the proxy" do
    let(:proxy) { "10.1.2.3" }

    before { behind("CF-Connecting-IP", trusted: %w[10.0.0.0/8]) }

    it "takes the address the proxy wrote" do
      expect(address("HTTP_CF_CONNECTING_IP" => client)).to eq(client)
    end
  end

  context "with a connection the listener names in IPv6" do
    let(:proxy) { "::ffff:127.0.0.1" }

    before { behind("CF-Connecting-IP") }

    it "matches the range the same, since it is the same address" do
      expect(address("HTTP_CF_CONNECTING_IP" => client)).to eq(client)
    end
  end

  context "with a connection that names no address" do
    let(:proxy) { "" }

    before { behind("CF-Connecting-IP") }

    it "trusts nothing, since there is nothing to match" do
      expect(address("HTTP_CF_CONNECTING_IP" => client)).to eq("")
    end
  end
end

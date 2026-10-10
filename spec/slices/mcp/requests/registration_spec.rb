# frozen_string_literal: true

require "digest"

RSpec.describe "Dynamic client registration", type: :request do
  let(:clients) { MCP::Slice["db.rom"].relations[:oauth_clients] }
  let(:limit) { Hanami.app["settings"].client_registration[:throttle_limit] }
  let(:redirect_uri) { "https://claude.ai/api/mcp/auth_callback" }

  def document = JSON.parse(last_response.body)

  def register(payload, env = {})
    body = payload.is_a?(String) ? payload : payload.to_json
    post "/oauth/register", body, { "CONTENT_TYPE" => "application/json" }.merge(env)
  end

  def stored_client = clients.with_client_id(document["client_id"]).one

  describe "a registration Claude sends" do
    before { register(client_name: "Claude", redirect_uris: [redirect_uri]) }

    it "accepts it" do
      expect(last_response.status).to eq(201)
    end

    it "answers with JSON" do
      expect(last_response.headers["Content-Type"]).to eq("application/json")
    end

    it "gives back a client ID" do
      expect(document["client_id"]).to be_a(String).and(satisfy { !it.empty? })
    end

    it "stores the client" do
      expect(stored_client).to include(client_name: "Claude")
    end

    it "stores the redirect URIs" do
      expect(stored_client[:redirect_uris]).to eq([redirect_uri])
    end

    it "gives back the redirect URIs" do
      expect(document["redirect_uris"]).to eq([redirect_uri])
    end

    it "says when the client ID was issued" do
      expect(document["client_id_issued_at"]).to be_within(60).of(Time.now.to_i)
    end

    it "registers the client as a public client" do
      expect(document["token_endpoint_auth_method"]).to eq("none")
    end

    it "hands out no client secret" do
      expect(document).not_to include("client_secret")
    end

    it "grants the authorization code and refresh token grants" do
      expect(document["grant_types"]).to eq(%w[authorization_code refresh_token])
    end

    it "answers the code response type" do
      expect(document["response_types"]).to eq(%w[code])
    end

    it "stores the registrant's daily hash rather than an address", :aggregate_failures do
      stored = stored_client[:visitor_hash]

      expect(stored).to eq(Analytics::Slice["operations.hash_visitor"].call(address: "127.0.0.1"))
      expect(stored).not_to eq(Digest::SHA256.hexdigest("127.0.0.1"))
    end
  end

  describe "a registration whose visitor hash comes back as the bare address" do
    before do
      bare = instance_double(Analytics::Operations::HashVisitor, throttle_hashes: ["127.0.0.1"])
      replace_component("analytics.operations.hash_visitor", bare)
    end

    it "refuses to store it" do
      expect { register(redirect_uris: [redirect_uri]) }.to raise_error(Dry::Types::ConstraintError)
    end

    def register_refused
      register(redirect_uris: [redirect_uri])
    rescue Dry::Types::ConstraintError
      nil
    end

    it "stores no client" do
      register_refused

      expect(clients.count).to eq(0)
    end
  end

  describe "a registration just after midnight from a registrant throttled just before it" do
    before do
      midnight = Blog::TimeZone.day_start(Blog::TimeZone.today + 1)
      allow(Time).to receive(:now).and_return(midnight - 600)
      limit.times { register(client_name: "Claude", redirect_uris: [redirect_uri]) }
      allow(Time).to receive(:now).and_return(midnight + 60)
      register(client_name: "Claude", redirect_uris: [redirect_uri])
    end

    it "comes back throttled" do
      expect(last_response.status).to eq(429)
    end

    it "stores no more than the limit" do
      expect(clients.count).to eq(limit)
    end
  end

  describe "a registration past the limit" do
    before do
      (limit + 1).times { register(client_name: "Claude", redirect_uris: [redirect_uri]) }
    end

    it "comes back throttled" do
      expect(last_response.status).to eq(429)
    end

    it "answers with JSON the client can read", :aggregate_failures do
      expect(last_response.headers["Content-Type"]).to eq("application/json")
      expect(document["error"]).to eq("temporarily_unavailable")
    end

    it "stores no more than the limit" do
      expect(clients.count).to eq(limit)
    end

    it "refuses a body it cannot read the same way, before it reads it" do
      register("")

      expect(last_response.status).to eq(429)
    end
  end

  describe "a run of registrations forging a forwarded address" do
    before do
      (limit + 1).times do |sent|
        register({ redirect_uris: [redirect_uri] }, "HTTP_X_FORWARDED_FOR" => "203.0.113.#{sent + 1}")
      end
    end

    it "comes back throttled once the limit is reached" do
      expect(last_response.status).to eq(429)
    end

    it "stores no more than the limit" do
      expect(clients.count).to eq(limit)
    end
  end

  describe "a registration from a second address" do
    before do
      limit.times { register({ redirect_uris: [redirect_uri] }, "REMOTE_ADDR" => "203.0.113.7") }
      register({ redirect_uris: [redirect_uri] }, "REMOTE_ADDR" => "198.51.100.4")
    end

    it "goes through, since the first address spent only its own allowance", :aggregate_failures do
      expect(last_response.status).to eq(201)
      expect(clients.count).to eq(limit + 1)
    end
  end

  describe "a run of registrations from one IPv6 /64 with a new address on each" do
    before do
      (limit + 1).times do |sent|
        register({ redirect_uris: [redirect_uri] }, "REMOTE_ADDR" => "2001:db8:1:2::#{sent + 1}")
      end
    end

    it "comes back throttled once the limit is reached" do
      expect(last_response.status).to eq(429)
    end

    it "stores no more than the limit" do
      expect(clients.count).to eq(limit)
    end

    it "keys the hash on the network rather than the address" do
      network = Analytics::Slice["operations.hash_visitor"].call(address: "2001:db8:1:2::")

      expect(clients.first[:visitor_hash]).to eq(network)
    end
  end

  describe "a registration from a second IPv6 /64" do
    before do
      limit.times { register({ redirect_uris: [redirect_uri] }, "REMOTE_ADDR" => "2001:db8:1:2::1") }
      register({ redirect_uris: [redirect_uri] }, "REMOTE_ADDR" => "2001:db8:1:3::1")
    end

    it "goes through, since the first network spent only its own allowance" do
      expect(last_response.status).to eq(201)
    end
  end

  describe "a run of registrations from many addresses past the total limit" do
    let(:total) { 3 }

    before do
      settings = Hanami.app["settings"]
      allow(settings).to receive(:client_registration)
        .and_return(settings.client_registration.merge(total_throttle_limit: total))
      (total + 1).times do |sent|
        register({ redirect_uris: [redirect_uri] }, "REMOTE_ADDR" => "203.0.113.#{sent + 1}")
      end
    end

    it "comes back throttled" do
      expect(last_response.status).to eq(429)
    end

    it "stores no more than the total limit" do
      expect(clients.count).to eq(total)
    end
  end

  describe "a registration that loses the last place across the site to one landing beside it" do
    let(:total) { 2 }

    before do
      settings = Hanami.app["settings"]
      allow(settings).to receive(:client_registration)
        .and_return(settings.client_registration.merge(total_throttle_limit: total))
      total.times { |sent| register({ redirect_uris: [redirect_uri] }, "REMOTE_ADDR" => "203.0.113.#{sent + 1}") }
      client_repo = MCP::Slice["repos.oauth_client_queries"]
      allow(client_repo).to receive(:count_since).and_return(total - 1)
      replace_component("repos.oauth_client_queries", client_repo)
      register({ redirect_uris: [redirect_uri] }, "REMOTE_ADDR" => "198.51.100.4")
    end

    it "comes back throttled" do
      expect(last_response.status).to eq(429)
    end

    it "stores no more than the total limit" do
      expect(clients.count).to eq(total)
    end
  end

  it "takes thirty from all senders together and refuses the next when no total limit is set", :aggregate_failures do
    31.times { |sent| register({ redirect_uris: [redirect_uri] }, "REMOTE_ADDR" => "203.0.113.#{sent + 1}") }

    expect(last_response.status).to eq(429)
    expect(clients.count).to eq(30)
  end

  it "names no origin that may read the answer" do
    register(redirect_uris: [redirect_uri])

    expect(last_response.headers).not_to include("Access-Control-Allow-Origin")
  end

  describe "a registration that loses the last place to one landing beside it" do
    before do
      limit.times { register(redirect_uris: [redirect_uri]) }
      client_repo = MCP::Slice["repos.oauth_client_queries"]
      allow(client_repo).to receive(:count_from_visitor_since).and_return(limit - 1)
      replace_component("repos.oauth_client_queries", client_repo)
      register(redirect_uris: [redirect_uri])
    end

    it "comes back throttled" do
      expect(last_response.status).to eq(429)
    end

    it "stores no more than the limit" do
      expect(clients.count).to eq(limit)
    end
  end

  describe "a registration once the window has passed" do
    let(:window) { Hanami.app["settings"].client_registration[:throttle_window_minutes] * 60 }

    before do
      limit.times { register(redirect_uris: [redirect_uri]) }
      clients.dataset.update(created_at: Time.now - window - 1)
      register(redirect_uris: [redirect_uri])
    end

    it "goes through" do
      expect(last_response.status).to eq(201)
    end
  end

  it "gives each client its own ID" do
    ids = Array.new(2) do
      register(redirect_uris: [redirect_uri])
      document["client_id"]
    end

    expect(ids.uniq).to have(2).items
  end

  it "settles the grants itself when the client asks for another one" do
    register(redirect_uris: [redirect_uri], grant_types: %w[client_credentials], token_endpoint_auth_method: "none")

    expect(document["grant_types"]).to eq(%w[authorization_code refresh_token])
  end

  describe "the redirect URIs it takes" do
    [
      "https://claude.ai/api/mcp/auth_callback",
      "http://localhost:53941/callback",
      "http://127.0.0.1:53941/callback",
      "http://[::1]:53941/callback",
      "https://claude.ai/callback?next=1",
    ].each do |uri|
      it "takes #{uri}" do
        register(redirect_uris: [uri])

        expect(last_response.status).to eq(201)
      end
    end

    it "takes more than one" do
      register(redirect_uris: ["http://localhost:1234/callback", "http://127.0.0.1:1234/callback"])

      expect(document["redirect_uris"]).to have(2).items
    end

    it "stores a padded URI in the form it validated" do
      register(redirect_uris: [" #{redirect_uri} "])

      expect(stored_client[:redirect_uris]).to eq([redirect_uri])
    end

    it "gives back a padded URI in the form it validated" do
      register(redirect_uris: [" #{redirect_uri} "])

      expect(document["redirect_uris"]).to eq([redirect_uri])
    end
  end

  describe "a registration it rejects" do
    {
      "no redirect URIs at all" => nil,
      "an empty list of redirect URIs" => [],
      "a redirect URI that is not a URI" => ["not a uri"],
      "a relative redirect URI" => ["/callback"],
      "a redirect URI with a fragment" => ["https://claude.ai/callback#code"],
      "a redirect URI with userinfo" => ["https://claude.ai@evil.example/callback"],
      "a redirect URI with a user and password" => ["https://user:secret@claude.ai/callback"],
      "a loopback redirect URI with userinfo" => ["http://claude.ai@localhost:53941/callback"],
      "a plain HTTP redirect URI on a host that starts like localhost" => ["http://localhost.evil.example/callback"],
      "a redirect URI in an app's own scheme" => ["claude://callback"],
      "a redirect URI with no host" => ["https://"],
      "an empty redirect URI" => [""],
      "a null redirect URI" => [nil],
      "a plain HTTP redirect URI on another host" => ["http://claude.ai/api/mcp/auth_callback"],
      "a redirect URI in another scheme" => ["ftp://claude.ai/callback"],
      "a redirect URI that is not a string" => [42],
      "redirect URIs that are not a list" => "https://claude.ai/api/mcp/auth_callback",
      "more redirect URIs than anyone needs" => Array.new(11) { |n| "https://claude.ai/callback/#{n}" },
    }.each do |description, uris|
      context "with #{description}" do
        before { register(uris.nil? ? { client_name: "Claude" } : { redirect_uris: uris }) }

        it "rejects it" do
          expect(last_response.status).to eq(400)
        end

        it "says the redirect URI is the problem" do
          expect(document["error"]).to eq("invalid_redirect_uri")
        end

        it "stores no client" do
          expect(clients.count).to eq(0)
        end
      end
    end
  end

  describe "a registration whose metadata it rejects" do
    {
      "a NUL in the client name" => { client_name: "Cla\u0000ude" },
      "a NUL in the client URI" => { client_uri: "https://clau\u0000de.ai" },
      "a NUL in the logo URI" => { logo_uri: "https://claude.ai/logo\u0000.png" },
      "a client name ten thousand characters long" => { client_name: "a" * 10_000 },
    }.each do |description, metadata|
      context "with #{description}" do
        before { register(redirect_uris: [redirect_uri], **metadata) }

        it "rejects it" do
          expect(last_response.status).to eq(400)
        end

        it "says the metadata is the problem" do
          expect(document["error"]).to eq("invalid_client_metadata")
        end

        it "explains itself" do
          expect(document["error_description"]).to include("control character")
        end

        it "stores no client" do
          expect(clients.count).to eq(0)
        end
      end
    end

    it "says the redirect URI is the problem when both are wrong" do
      register(redirect_uris: ["/callback"], client_name: "Cla\u0000ude")

      expect(document["error"]).to eq("invalid_redirect_uri")
    end
  end

  describe "a body it cannot read" do
    it "rejects a body that is not JSON" do
      register("redirect_uris=https://claude.ai")

      expect(last_response.status).to eq(400)
    end

    it "rejects an empty body" do
      register("")

      expect(last_response.status).to eq(400)
    end

    it "rejects a body that is not an object" do
      register(%w[https://claude.ai/api/mcp/auth_callback])

      expect(last_response.status).to eq(400)
    end

    it "says the metadata is the problem" do
      register("")

      expect(document["error"]).to eq("invalid_client_metadata")
    end

    it "explains itself" do
      register("")

      expect(document["error_description"]).to be_a(String).and(satisfy { !it.empty? })
    end
  end

  it "answers only to POST" do
    get "/oauth/register"

    expect(last_response.status).to eq(405)
  end

  describe "the length of the metadata" do
    let(:cap) { MCP::Contracts::ClientRegistrationContract::MAX_URI }
    let(:name_cap) { MCP::Contracts::ClientRegistrationContract::MAX_NAME }

    it "takes a client name at the cap" do
      register(redirect_uris: [redirect_uri], client_name: "a" * name_cap)

      expect(last_response.status).to eq(201)
    end

    it "rejects a client name one past the cap" do
      register(redirect_uris: [redirect_uri], client_name: "a" * (name_cap + 1))

      expect(document["error"]).to eq("invalid_client_metadata")
    end

    %i[client_uri logo_uri].each do |field|
      it "rejects a #{field} past the cap" do
        register(redirect_uris: [redirect_uri], field => "https://claude.ai/#{'a' * cap}")

        expect(document["error"]).to eq("invalid_client_metadata")
      end
    end

    it "takes a registration that names nothing but its redirect URIs" do
      register(redirect_uris: [redirect_uri])

      expect(last_response.status).to eq(201)
    end
  end
end

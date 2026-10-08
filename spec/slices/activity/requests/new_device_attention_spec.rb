# frozen_string_literal: true

RSpec.describe "New devices on the attention list", :frozen_clock, type: :request do
  let(:minted) { API::Slice["operations.mint_token"].call(name: "Terminal").value! }

  before do
    use_country_database
    write_country_database
    allow(Hanami.app.settings).to receive(:proxy)
      .and_return(address_header: "CF-Connecting-IP", trusted_proxies: [IPAddr.new("127.0.0.0/8")])
  end

  def access_headers(user_agent, address = "81.2.69.160")
    { "HTTP_USER_AGENT" => user_agent, "HTTP_CF_CONNECTING_IP" => address }
  end

  def agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36"

  def call_api(address: "81.2.69.160", user_agent: agent)
    get "/api/v1/token", {},
        { "HTTP_AUTHORIZATION" => "Bearer #{minted[:value]}", **access_headers(user_agent, address) }
  end

  def firefox = "Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0"

  def known_devices = security_table(:known_devices)

  def new_city
    call_api
    call_api(address: "198.51.100.7")
  end

  def rows = stalled.select { it.kind == "new_device" }

  def security_table(name) = Security::Slice["db.rom"].gateways[:default].connection[name]

  def snooze(record_id) = Activity::Slice["operations.snooze_attention"].call("new_device", record_id)

  def stalled = Activity::Slice["repos.attention_queries"].stalled

  def titles = rows.map(&:title)

  describe "an API token" do
    it "adds nothing for the token's first device" do
      call_api

      expect(rows).to eq([])
    end

    it "adds a row for a city the token has not called from" do
      new_city

      expect(titles).to eq(["API token Terminal: Chrome on macOS in Nowhere"])
    end

    it "adds a row for a device the token has not called from" do
      call_api
      call_api(user_agent: "curl/8.7.1")

      expect(titles).to eq(["API token Terminal: an unknown device in London, GB"])
    end

    it "adds nothing for a device and city the token already used" do
      new_city
      known_devices.update(created_at: days_ago(30))
      call_api(address: "198.51.100.7")

      expect(rows).to eq([])
    end

    it "adds nothing for a known device once its sightings are pruned" do
      new_city
      known_devices.update(created_at: days_ago(30))
      security_table(:sightings).delete
      call_api(address: "198.51.100.7")

      expect([rows, security_table(:sightings).count]).to eq([[], 1])
    end

    it "keeps the row for seven days" do
      new_city
      known_devices.where(city: "Nowhere").update(created_at: days_ago(6))

      expect(rows.map(&:days)).to eq([6])
    end

    it "drops the row after seven days" do
      new_city
      known_devices.where(city: "Nowhere").update(created_at: days_ago(7))

      expect(rows).to eq([])
    end

    it "ranks the row above stalled work" do
      create(:task, carried_count: 9)
      new_city

      expect(stalled.map(&:kind)).to eq(%w[new_device carried])
    end

    it "takes the row off the list when snoozed" do
      new_city
      snooze(rows.first.record_id)

      expect(rows).to eq([])
    end

    it "drops the row's snooze when the token goes" do
      new_city
      snooze(rows.first.record_id)
      API::Slice["db.rom"].gateways[:default].connection[:api_tokens].delete

      expect([known_devices.count, Activity::Slice["db.rom"].relations[:attention_snoozes].count]).to eq([0, 0])
    end
  end

  describe "an MCP client" do
    let(:token) { Blog::SecretToken.generate }

    before do
      factories = Spec::DB::Factories[:mcp]
      factories.create(
        :oauth_token, oauth_client: factories.create(:oauth_client, client_name: "Claude"),
                      token_digest: Blog::SecretToken.digest(token), resource: Hanami.app.settings.site_url("/mcp"),
      )
      [agent, firefox].each { call_mcp(it) }
    end

    def call_mcp(user_agent)
      post "/mcp", JSON.generate(jsonrpc: "2.0", id: 1, method: "tools/list"), {
        "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{token}", **access_headers(user_agent),
      }
    end

    it "adds a row for a device the client has not called from" do
      expect(titles).to eq(["MCP client Claude: Firefox on Linux in London, GB"])
    end

    it "returns the row from list_attention, its title marked untrusted" do
      record_id = known_devices.max(:id)
      title = { "untrusted" => true, "text" => "MCP client Claude: Firefox on Linux in London, GB" }

      expect(mcp_answer("list_attention").fetch("attention")).to eq(
        [{ "kind" => "new_device", "record_id" => record_id, "carried_count" => nil, "days" => 0, "title" => title }],
      )
    end
  end

  describe "a sign-in" do
    def callback(user_agent)
      get "/admin/sign-in"
      state = Rack::Utils.parse_query(URI(last_response.location).query).fetch("state")
      get "/admin/auth/github/callback", { code: "code", state: }, access_headers(user_agent)
    end

    def card_row = Capybara.string(last_response.body).find("section.card[data-attention] .li")

    def card_shows
      row = card_row
      [row.find(".li-title").text, row.find(".li-sub").text, row.has_css?("input[value=new_device]", visible: :all)]
    end

    def sign_in(user_agent)
      stub_github_sign_in
      callback(user_agent)
    end

    def wrong_account(user_agent)
      stub_request(:get, "https://api.github.com/user")
        .to_return(headers: { "Content-Type" => "application/json" }, body: { id: 1 }.to_json)
      callback(user_agent)
    end

    it "adds a row for a device the operator has not signed in from" do
      sign_in(agent)
      sign_in(firefox)

      expect(titles).to eq(["Sign-in: Firefox on Linux in London, GB"])
    end

    it "adds nothing for a failed sign-in from a new device" do
      sign_in(agent)
      wrong_account(firefox)

      expect([rows, security_table(:sign_ins).select_map(:outcome)]).to eq([[], %w[signed_in wrong_account]])
    end

    it "shows the row on the admin card with a snooze" do
      [agent, firefox].each { sign_in(it) }
      sign_in_to_admin
      get "/admin"

      expect(card_shows).to eq(["Sign-in: Firefox on Linux in London, GB", "New device or place today", true])
    end
  end
end

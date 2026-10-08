# frozen_string_literal: true

RSpec.describe "Admin MCP clients", type: :request do
  let(:codes) { MCP::Slice["db.rom"].relations[:oauth_codes] }
  let(:page) { Capybara.string(last_response.body) }
  let(:tokens) { MCP::Slice["db.rom"].relations[:oauth_tokens] }

  def listed
    get "/admin/clients"
    Capybara.string(last_response.body).all(".li-title").map(&:text)
  end

  def mcp_create(name, *traits, **) = Spec::DB::Factories[:mcp].create(name, *traits, **)

  def names = page.all(".li-title").map(&:text)

  def revoke(id) = post("/admin/clients/#{id}/revoke", _csrf_token: admin_csrf_token)

  def row = page.first(".li")

  def stock_code(client)
    MCP::Slice["repos.oauth_code_mutations"].issue(
      code: Blog::Types::NewSecret[],
      code_challenge: "a" * 43,
      expires_at: Time.now + 60,
      oauth_client_id: client.id,
      redirect_uri: client.redirect_uris.first,
    )
  end

  def stock_token(client, type:)
    MCP::Slice["repos.oauth_token_mutations"].issue(
      token: Blog::Types::NewSecret[],
      type:,
      oauth_client_id: client.id,
      expires_at: Time.now + 60,
    )
  end

  describe "signed out" do
    it "sends me to sign-in" do
      get "/admin/clients"

      expect(last_response.location).to end_with("/admin/sign-in")
    end

    it "refuses a revoke and leaves the tokens alone" do
      client = mcp_create(:oauth_client)
      stock_token(client, type: "access")
      post "/admin/clients/#{client.id}/revoke"

      expect(tokens.for_client(client.id).count).to eq(1)
    end
  end

  describe "the list" do
    let(:connected) { Time.now - (3 * 24 * 60 * 60) }
    let(:used) { Time.now - (60 * 60) }

    before { sign_in_to_admin }

    def connect(*, **)
      mcp_create(:oauth_client, *, **).tap { mcp_create(:oauth_token, oauth_client: it) }
    end

    it "says so when nothing has connected" do
      get "/admin/clients"

      expect(page).to have_css(".empty")
    end

    it "lists every client holding a live token, newest first" do
      connect(client_name: "Older", created_at: Time.now - 60)
      connect(client_name: "Newer")
      get "/admin/clients"

      expect(names).to eq(%w[Newer Older])
    end

    it "counts only the clients it lists" do
      connect(client_name: "Claude")
      mcp_create(:oauth_client, client_name: "Stranger")
      get "/admin/clients"

      expect(page).to have_css(".card-side", exact_text: "1 connected client")
    end

    it "leaves out a registration that never got a token" do
      mcp_create(:oauth_client, client_name: "Stranger")
      get "/admin/clients"

      expect(names).to be_empty
    end

    it "leaves out a client whose tokens have all expired" do
      mcp_create(:oauth_token, :expired, oauth_client: mcp_create(:oauth_client, client_name: "Lapsed"))
      get "/admin/clients"

      expect(names).to be_empty
    end

    it "leaves out a client whose tokens have all been revoked" do
      mcp_create(:oauth_token, :revoked, oauth_client: mcp_create(:oauth_client, client_name: "Signed out"))
      get "/admin/clients"

      expect(names).to be_empty
    end

    it "keeps a client whose access token lapsed while its refresh token lives" do
      client = mcp_create(:oauth_client, client_name: "Claude")
      mcp_create(:oauth_token, :expired, oauth_client: client)
      mcp_create(:oauth_token, :refresh, oauth_client: client)
      get "/admin/clients"

      expect(names).to eq(%w[Claude])
    end

    it "lists a client once however many tokens it holds" do
      connect(client_name: "Claude").then { mcp_create(:oauth_token, :refresh, oauth_client: it) }
      get "/admin/clients"

      expect(names).to eq(%w[Claude])
    end

    it "shows the redirect host beside the client name", :aggregate_failures do
      connect(client_name: "Claude", redirect_uris: %w[https://claude.ai/api/mcp/auth_callback])
      get "/admin/clients"

      expect(names).to eq(%w[Claude])
      expect(page.find(".li-sub")).to have_text(/\Aclaude\.ai · connected/)
    end

    it "tells apart two clients that registered the same name" do
      connect(client_name: "Claude", redirect_uris: %w[https://claude.ai/api/mcp/auth_callback])
      connect(client_name: "Claude", redirect_uris: %w[https://evil.example/callback])
      get "/admin/clients"

      expect(page.all(".li-sub").map { it.text.split(" · ").first }).to contain_exactly("claude.ai", "evil.example")
    end

    it "shows when the client connected" do
      connect(client_name: "Claude", created_at: connected)
      get "/admin/clients"

      expect(row).to have_text("connected #{Blog::TimeZone.local(connected).strftime('%b %-d, %Y, %H:%M')}")
    end

    it "links each client to its sightings" do
      connect(client_name: "Claude")
      get "/admin/clients"

      expect(row).to have_link("sightings →", href: "/admin/security")
    end

    it "shows when the client was last used" do
      connect(client_name: "Claude", last_used_at: used)
      get "/admin/clients"

      expect(row).to have_text("last used #{Blog::TimeZone.local(used).strftime('%b %-d, %Y, %H:%M')}")
    end

    it "puts when the client connected and was last used in time tags" do
      connect(client_name: "Claude", created_at: connected, last_used_at: used)
      get "/admin/clients"

      expect(row.all(".li-sub time").map { it[:datetime] })
        .to eq([Blog::TimeZone.local(connected).iso8601, Blog::TimeZone.local(used).iso8601])
    end

    it "says a client that never made a request has never been used" do
      connect(client_name: "Claude", last_used_at: nil)
      get "/admin/clients"

      expect(row).to have_text("never used")
    end

    it "falls back to the redirect host when the client registered no name", :aggregate_failures do
      connect(client_name: nil, redirect_uris: %w[https://claude.ai/api/mcp/auth_callback])
      get "/admin/clients"

      expect(names).to eq(%w[claude.ai])
      expect(page.find(".li-sub")).to have_text(/\Aconnected/)
    end

    it "falls back to the client id when the redirect uri has no host it can read", :aggregate_failures do
      client = connect(client_name: nil, redirect_uris: ["not a uri"])
      get "/admin/clients"

      expect(last_response).to be_ok
      expect(names).to eq([client.client_id])
    end

    it "leaves out a client that was already revoked" do
      connect(:revoked, client_name: "Gone")
      get "/admin/clients"

      expect(names).to be_empty
    end
  end

  describe "revoking" do
    let(:client) { mcp_create(:oauth_client, client_name: "Claude") }

    before { sign_in_to_admin }

    it "asks for confirmation before it posts" do
      stock_token(client, type: "access")
      get "/admin/clients"

      expect(page).to have_css(
        "form[action='/admin/clients/#{client.id}/revoke'][data-confirm*='Revoke access for Claude']",
      )
    end

    it "deletes the client's tokens" do
      stock_token(client, type: "access")
      stock_token(client, type: "refresh")
      revoke(client.id)

      expect(tokens.for_client(client.id).count).to be_zero
    end

    it "deletes the client's codes" do
      stock_code(client)
      revoke(client.id)

      expect(codes.for_client(client.id).count).to be_zero
    end

    it "leaves another client's tokens alone" do
      other = mcp_create(:oauth_client, client_name: "Other")
      stock_token(other, type: "access")
      revoke(client.id)

      expect(tokens.for_client(other.id).count).to eq(1)
    end

    it "takes the client off the page" do
      stock_token(client, type: "access")
      stock_token(client, type: "refresh")

      expect { revoke(client.id) }.to change(self, :listed).from(%w[Claude]).to([])
    end

    it "keeps the client registered so it can sign in again" do
      revoke(client.id)

      expect(MCP::Slice["repos.oauth_client_queries"].connected_by_id(client.id)).not_to be_nil
    end

    it "says so and returns to the page", :aggregate_failures do
      revoke(client.id)

      expect(last_response.location).to eq("/admin/clients")
      follow_redirect!
      expect(page).to have_css("[data-toast]", text: "Access revoked")
    end

    it "answers 404 for a client it does not know" do
      revoke(0)

      expect(last_response.status).to eq(404)
    end

    it "answers 404 for a client that was already revoked" do
      revoke(mcp_create(:oauth_client, :revoked).id)

      expect(last_response.status).to eq(404)
    end
  end

  it "links to the page from Today" do
    sign_in_to_admin
    get "/admin"

    expect(page).to have_link("MCP clients", href: "/admin/clients")
  end
end

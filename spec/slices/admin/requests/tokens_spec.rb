# frozen_string_literal: true

RSpec.describe "Admin API tokens", type: :request do
  let(:stored) { API::Slice["db.rom"].relations[:api_tokens] }

  def call_api(value) = get("/api/v1/token", {}, { "HTTP_AUTHORIZATION" => "Bearer #{value}" })

  def checked(*scopes) = Blog::Types::OAuthScope.values.to_h { [it, scopes.include?(it) ? "1" : "0"] }

  def error(code, field = "name") = Admin::Slice["i18n"].t(["ui.components.tokens.field_error", field, code].join("."))

  def mint(name, **fields) = post("/admin/tokens", token: { name:, **fields }, _csrf_token: admin_csrf_token)

  def minted(name = "Terminal") = API::Slice["operations.mint_token"].call(name:).value!

  def names = page.all(".li-title").map(&:text)

  def page = Capybara.string(last_response.body)

  def revealed = page.first("#minted-token")&.[](:value)

  def revoke(id) = post("/admin/tokens/#{id}/revoke", _csrf_token: admin_csrf_token)

  def row = page.first(".li")

  def stamp(time) = Blog::TimeZone.local(time).strftime("%b %-d, %Y, %H:%M")

  describe "signed out" do
    it "sends me to sign-in" do
      get "/admin/tokens"

      expect(last_response.location).to end_with("/admin/sign-in")
    end

    it "mints nothing" do
      post "/admin/tokens", token: { name: "Terminal" }

      expect(stored.count).to be_zero
    end

    it "leaves a token live" do
      token = minted[:token]
      post "/admin/tokens/#{token.id}/revoke"

      expect(stored.by_pk(token.id).one[:revoked_at]).to be_nil
    end
  end

  describe "minting" do
    before { sign_in_to_admin }

    it "stores the token under its name" do
      mint("Terminal")

      expect(stored.one[:name]).to eq("Terminal")
    end

    it "returns to the page with a toast", :aggregate_failures do
      mint("Terminal")

      expect(last_response.location).to eq("/admin/tokens")
      follow_redirect!
      expect(page).to have_css("[data-toast]", text: "Token minted")
    end

    it "shows the token's value once" do
      mint("Terminal")
      follow_redirect!

      expect(Blog::Types::SecretDigest[revealed]).to eq(stored.one[:token_digest])
    end

    it "stores a SHA-256 digest of the value" do
      mint("Terminal")
      follow_redirect!

      expect(stored.one[:token_digest]).to eq(Digest::SHA256.hexdigest(revealed))
    end

    it "never stores the value itself" do
      mint("Terminal")
      follow_redirect!

      expect(stored.one.values).not_to include(revealed)
    end

    it "mints a new value each time" do
      values = Array.new(2) { mint("Terminal").then { follow_redirect! }.then { revealed } }

      expect(values.uniq.size).to eq(2)
    end

    it "trims the name" do
      mint("  Laptop  ")

      expect(stored.one[:name]).to eq("Laptop")
    end

    it "shows a value the API takes" do
      mint("Terminal")
      follow_redirect!
      call_api(revealed)

      expect(last_response.status).to eq(200)
    end

    it "hides the value on a reload" do
      mint("Terminal")
      follow_redirect!
      get "/admin/tokens"

      expect(page).to have_no_css("#minted-token")
    end

    it "keeps the value out of the page on a reload" do
      mint("Terminal")
      value = follow_redirect!.then { revealed }
      get "/admin/tokens"

      expect(last_response.body).not_to include(value)
    end

    it "shows no value before I mint" do
      minted
      get "/admin/tokens"

      expect(page).to have_no_css("#minted-token")
    end

    it "refuses a blank name and says why", :aggregate_failures do
      mint("   ")

      expect(last_response.status).to eq(422)
      expect(page).to have_css(".field-error", text: error("blank"))
    end

    it "refuses a name made only of Unicode spaces and says why", :aggregate_failures do
      mint("\u2003\u3000")

      expect(last_response.status).to eq(422)
      expect(page).to have_css(".field-error", text: error("blank"))
    end

    it "refuses a name over 100 characters and keeps what I typed", :aggregate_failures do
      mint("a" * 101)

      expect(page).to have_css(".field-error", text: error("long"))
      expect(page).to have_field("token[name]", with: "a" * 101)
    end

    it "stores nothing when it refuses" do
      mint("")

      expect(stored.count).to be_zero
    end

    it "stores the scopes I check" do
      mint("Terminal", scopes: checked("read", "write"))

      expect(stored.one[:scopes]).to eq(%w[read write])
    end

    it "checks only read on a fresh form" do
      get "/admin/tokens"

      expect(page.all("input[type=checkbox][checked]").map { it[:name] }).to eq(["token[scopes][read]"])
    end

    it "refuses a token with no scope and says why", :aggregate_failures do
      mint("Terminal", scopes: checked)

      expect(last_response.status).to eq(422)
      expect(page).to have_css(".field-error", text: error("blank", "scopes"))
    end

    it "keeps the scopes I checked when it refuses" do
      mint("", scopes: checked("publish"))

      expect(page.all("input[type=checkbox][checked]").map { it[:name] }).to eq(["token[scopes][publish]"])
    end

    it "stores no expiry when I leave the day blank" do
      mint("Terminal", scopes: checked("read"), expires_on: "")

      expect(stored.one[:expires_at]).to be_nil
    end

    it "expires the token at local midnight on the day I pick" do
      day = Blog::TimeZone.today + 7
      mint("Terminal", scopes: checked("read"), expires_on: day.iso8601)

      expect(stored.one[:expires_at]).to eq(Blog::TimeZone.day_start(day))
    end

    it "refuses an expiry of today and says why", :aggregate_failures do
      mint("Terminal", scopes: checked("read"), expires_on: Blog::TimeZone.today.iso8601)

      expect(last_response.status).to eq(422)
      expect(page).to have_css(".field-error", text: error("past", "expires_on"))
    end

    it "refuses an expiry that is not a day" do
      mint("Terminal", scopes: checked("read"), expires_on: "soon")

      expect(page).to have_css(".field-error", text: error("format", "expires_on"))
    end

    it "lists the live tokens beside the errors" do
      minted("Laptop")
      mint("")

      expect(names).to eq(%w[Laptop])
    end
  end

  describe "the list" do
    before { sign_in_to_admin }

    it "says so when no token is live" do
      get "/admin/tokens"

      expect(page).to have_css(".empty")
    end

    it "lists each live token by name, newest first" do
      older = minted("Older")[:token]
      minted("Newer")
      stored.where(id: older.id).update(created_at: Time.now - 60)
      get "/admin/tokens"

      expect(names).to eq(%w[Newer Older])
    end

    it "counts the live tokens" do
      minted("Laptop")
      minted("Desktop")
      get "/admin/tokens"

      expect(page).to have_css(".card-side", exact_text: "2 live tokens")
    end

    it "leaves out a revoked token" do
      API::Slice["operations.revoke_token"].call(minted("Gone")[:token].id)
      get "/admin/tokens"

      expect(names).to be_empty
    end

    it "shows when I minted the token" do
      token = minted[:token]
      get "/admin/tokens"

      expect(row).to have_text("minted #{stamp(token.created_at)}")
    end

    it "shows when a client last used the token" do
      used = Time.now - (60 * 60)
      stored.where(id: minted[:token].id).update(last_used_at: used)
      get "/admin/tokens"

      expect(row).to have_text("last used #{stamp(used)}")
    end

    it "names when I minted the token in local time" do
      token = minted[:token]
      get "/admin/tokens"

      expect(row.find("time")[:datetime]).to eq(Blog::TimeZone.local(token.created_at).iso8601)
    end

    it "names each token's scopes" do
      API::Slice["operations.mint_token"].call(name: "Terminal", scopes: %w[read publish])
      get "/admin/tokens"

      expect(row).to have_text("read, publish")
    end

    it "says a token with no expiry never expires" do
      minted
      get "/admin/tokens"

      expect(row).to have_text("never expires")
    end

    it "shows when a token expires" do
      day = Blog::TimeZone.today + 7
      API::Slice["operations.mint_token"].call(name: "Terminal", expires_on: day)
      get "/admin/tokens"

      expect(row).to have_text("expires #{stamp(Blog::TimeZone.day_start(day))}")
    end

    it "leaves out an expired token" do
      stored.where(id: minted[:token].id).update(expires_at: Time.now - 1)
      get "/admin/tokens"

      expect(names).to be_empty
    end

    it "says a token no client has used has never been used" do
      minted
      get "/admin/tokens"

      expect(row).to have_text("never used")
    end

    it "never shows a token's value" do
      value = minted[:value]
      get "/admin/tokens"

      expect(last_response.body).not_to include(value)
    end
  end

  describe "revoking" do
    let(:token) { minted("Laptop")[:token] }

    before { sign_in_to_admin }

    it "asks for confirmation before it posts" do
      token
      get "/admin/tokens"

      expect(page).to have_css("form[action='/admin/tokens/#{token.id}/revoke'][data-confirm*='Revoke Laptop']")
    end

    it "stamps the token revoked" do
      revoke(token.id)

      expect(stored.by_pk(token.id).one[:revoked_at]).not_to be_nil
    end

    it "takes the token off the page" do
      revoke(token.id)
      get "/admin/tokens"

      expect(names).to be_empty
    end

    it "cuts the token off from the API" do
      value, token = minted.values_at(:value, :token)
      revoke(token.id)
      call_api(value)

      expect(last_response.status).to eq(401)
    end

    it "leaves another token live" do
      other = minted("Desktop")[:token]
      revoke(token.id)

      expect(stored.by_pk(other.id).one[:revoked_at]).to be_nil
    end

    it "says so and returns to the page", :aggregate_failures do
      revoke(token.id)

      expect(last_response.location).to eq("/admin/tokens")
      follow_redirect!
      expect(page).to have_css("[data-toast]", text: "Token revoked")
    end

    it "answers 404 for a token it does not know" do
      revoke(0)

      expect(last_response.status).to eq(404)
    end

    it "answers 404 for a token it already revoked" do
      revoke(token.id)
      revoke(token.id)

      expect(last_response.status).to eq(404)
    end
  end

  it "is a section of the command palette" do
    sign_in_to_admin
    get "/admin"

    expect(page).to have_css("[data-palette-href='/admin/tokens']", visible: :all)
  end
end

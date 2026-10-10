# frozen_string_literal: true

RSpec.describe "Admin security", type: :request do
  let(:database) { Security::Slice["db.rom"].gateways[:default].connection }
  let(:page) { Capybara.string(last_response.body) }

  def card(title) = page.find(".card", text: title)

  def client(name) = mcp_create(:oauth_client, client_name: name).tap { mcp_create(:oauth_token, oauth_client: it) }

  def credential(name) = page.find(".security-cred", text: name)

  def mcp_create(name, *traits, **) = Spec::DB::Factories[:mcp].create(name, *traits, **)

  def sight(**row)
    database[:sightings].insert(
      browser: "Firefox", os: "Linux", city: "London", country: "GB", calls: 3, last_address: "81.2.69.160",
      last_user_agent: "Firefox/141", first_seen_at: Time.now - 3600, last_seen_at: Time.now, **row,
    )
  end

  def sign_in_row(**row)
    database[:sign_ins].insert(
      outcome: "signed_in", address: "81.2.69.160", user_agent: "Chrome/141", browser: "Chrome", os: "macOS",
      city: "London", country: "GB", **row,
    )
  end

  def token(name) = API::Slice["operations.mint_token"].call(name:).value![:token]

  describe "signed in" do
    before { sign_in_to_admin }

    it "says so when nobody has signed in" do
      get "/admin/security"

      expect(card("Sign-ins")).to have_css(".empty")
    end

    it "lists sign-ins newest first" do
      sign_in_row(browser: "Safari", created_at: Time.now - 60)
      sign_in_row(browser: "Firefox", outcome: "wrong_account")
      get "/admin/security"

      expect(card("Sign-ins").all(".li-title").map(&:text)).to eq(["Firefox · macOS", "Safari · macOS"])
    end

    it "shows each sign-in's outcome, place, address and time" do
      sign_in_row(outcome: "wrong_account", address: "203.0.113.9", city: "Paris", country: "FR")
      get "/admin/security"

      expect(card("Sign-ins").find(".li")).to have_text("wrong account").and have_text("Paris · FR · 203.0.113.9")
        .and have_css("time")
    end

    it "pills a sign-in green when it went through and pink when it did not", :aggregate_failures do
      sign_in_row(browser: "Safari", created_at: Time.now - 60)
      sign_in_row(browser: "Firefox", outcome: "denied")
      get "/admin/security"

      expect(card("Sign-ins").find(".li", text: "Safari")).to have_css(".pill.green", exact_text: "signed in")
      expect(card("Sign-ins").find(".li", text: "Firefox")).to have_css(".pill.pink", exact_text: "denied")
    end

    it "shows a sign-in's country by name when it has one" do
      sign_in_row(country_name: "United Kingdom")
      get "/admin/security"

      expect(card("Sign-ins").find(".li")).to have_text("London · United Kingdom · 81.2.69.160")
    end

    it "names a device and place it could not read" do
      sign_in_row(browser: nil, os: nil, city: nil, country: nil)
      get "/admin/security"

      expect(card("Sign-ins").find(".li")).to have_text("Unknown device").and have_text("Unknown place")
    end

    it "lists a token's sightings with place, calls, address and both times" do
      sight(api_token_id: token("Terminal").id)
      get "/admin/security"

      expect(credential("Terminal").find(".li")).to have_css(".li-title", text: "Firefox · Linux")
        .and have_text("London · GB · 3 calls · 81.2.69.160").and have_text("first seen").and have_text("last seen")
        .and have_css("time", count: 2)
    end

    it "shows a sighting's country by name when it has one" do
      sight(api_token_id: token("Terminal").id, country_name: "United Kingdom")
      get "/admin/security"

      expect(credential("Terminal").find(".li")).to have_text("London · United Kingdom · 3 calls")
    end

    it "names a sighting's device and place it could not read" do
      sight(api_token_id: token("Terminal").id, browser: nil, os: nil, city: nil, country: nil)
      get "/admin/security"

      expect(credential("Terminal").find(".li")).to have_text("Unknown device").and have_text("Unknown place")
    end

    it "lists an MCP client's sightings under that client" do
      found = client("Claude")
      sight(oauth_client_id: found.id, browser: "Chrome")
      sight(api_token_id: token("Terminal").id)
      get "/admin/security"

      expect(credential("Claude").all(".li-title").map(&:text)).to eq(["Chrome · Linux"])
    end

    it "shows a credential nothing has used" do
      token("Terminal")
      get "/admin/security"

      expect(credential("Terminal")).to have_css(".empty")
    end

    it "links to the Honeybadger project when one is set" do
      allow(Hanami.app.settings).to receive(:honeybadger).and_return(project_url: "https://app.honeybadger.io/projects/1")
      get "/admin/security"

      expect(page).to have_link("Errors on Honeybadger", href: "https://app.honeybadger.io/projects/1")
    end

    it "leaves the Honeybadger link out when no project is set" do
      get "/admin/security"

      expect(page).to have_no_link("Errors on Honeybadger")
    end

    it "shows in the navigation" do
      get "/admin/security"

      expect(page).to have_css("[data-palette-href='/admin/security']", visible: :all)
    end
  end
end

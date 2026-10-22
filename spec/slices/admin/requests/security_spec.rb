# frozen_string_literal: true

RSpec.describe "Admin security", type: :request do
  let(:database) { Security::Slice["db.rom"].gateways[:default].connection }
  let(:page) { Capybara.string(last_response.body) }

  def card(title) = page.find(".card", text: title)

  def client(name) = create(:oauth_client, client_name: name).tap { create(:oauth_token, oauth_client: it) }

  def confirm_sign_out(device) = Admin::Slice["i18n"].t("ui.components.security.device_row.confirm_sign_out", device:)

  def credential(name) = page.find(".security-cred", text: name)

  def device(**row) = database[:devices].returning(:id).insert(browser: "Safari", os: "iOS", **row).first[:id]

  def rows = card("Sign-ins").all(".li").reject { it.has_css?(".li-title", exact_text: "Owner · Spec") }

  def settings_tabs = page.all("nav[aria-label='Settings tabs'] a.screen-tab").map { it["href"] }

  def sight(**row)
    database[:sightings].insert(
      browser: "Firefox", os: "Linux", city: "London", country: "GB", calls: 3, last_address: "81.2.69.160",
      last_user_agent: "Firefox/141", first_seen_at: Time.now - 3600, last_seen_at: Time.now, **row,
    )
  end

  def sign_in_row(**row)
    database[:sign_ins].insert(
      outcome: "signed_in", provider: "github", address: "81.2.69.160", user_agent: "Chrome/141", browser: "Chrome",
      os: "macOS", city: "London", country: "GB", **row,
    )
  end

  def tabs
    {
      "tagging 0" => "/admin/settings/tagging", "webmentions" => "/admin/settings/webmentions",
      "connected services #{Admin::Slice['operations.list_services'].count}" => "/admin/settings/services",
      "jobs 0" => "/admin/settings/jobs", "security" => "/admin/settings/security",
    }.to_a
  end

  def titles = rows.map { it.find(".li-title").text }

  def token(name) = API::Slice["operations.mint_token"].call(name:).value![:token]

  describe "signed in" do
    before { sign_in_to_admin }

    it "draws the security tab of the Settings page", :aggregate_failures do
      get "/admin/settings/security"

      expect(page).to have_css(".page-head h1", exact_text: "Settings")
      expect(page.all("nav[aria-label='Settings tabs'] a.screen-tab").map { [it.text, it["href"]] }).to eq(tabs)
      expect(page).to have_css("nav[aria-label='Settings tabs'] a[aria-current='page']", exact_text: "security")
    end

    it "lists every Settings tab in order" do
      get "/admin/settings/security"

      expect(settings_tabs).to eq(%w[tagging webmentions services jobs security].map { "/admin/settings/#{it}" })
    end

    it "lands Settings on its first tab" do
      get "/admin/settings"

      expect([last_response.status, last_response.location]).to eq([302, "/admin/settings/tagging"])
    end

    it "sends the old socials address to the webmentions tab" do
      get "/admin/settings/socials"

      expect([last_response.status, last_response.location]).to eq([302, "/admin/settings/webmentions"])
    end

    it "sends the old security address to the tab" do
      get "/admin/security"

      expect([last_response.status, last_response.location]).to eq([302, "/admin/settings/security"])
    end

    it "lists only this browser when nothing else has signed in" do
      get "/admin/settings/security"

      expect(card("Sign-ins").all(".li-title").map(&:text)).to eq(["Owner · Spec"])
    end

    it "says it lists every sign-in, failed ones too, and where each token called from", :aggregate_failures do
      sign_in_row(outcome: "denied")
      sight(api_token_id: token("Terminal").id)
      get "/admin/settings/security"
      expect(page).to have_css(".settings-aside", exact_text: Admin::Slice["i18n"].t("ui.views.security.show.sub"))
      expect([card("Sign-ins"), credential("Terminal")]).to all(have_css(".li"))
    end

    describe "a browser that signed in three times" do
      let!(:phone) { device(last_signed_in_at: Time.now - 60) }

      before do
        sign_in_row(device_id: phone, city: "Austin", country: "US", created_at: Time.now - 3600)
        sign_in_row(device_id: phone, city: "Austin", country: "US", created_at: Time.now - 600)
        sign_in_row(device_id: phone, provider: "google", city: "Paris", country: "FR", address: "203.0.113.9",
                    created_at: Time.now - 60)
        get "/admin/settings/security"
      end

      it "shows as one device row" do
        expect(titles).to eq(["Safari · iOS"])
      end

      it "shows the place and time of its last sign-in", :aggregate_failures do
        row = rows.first

        expect(row).to have_text("Google · Paris · FR · 203.0.113.9")
        expect(Time.iso8601(row.find("time")["datetime"])).to be_within(2).of(Time.now - 60)
        expect(row).to have_css(".pill.green", exact_text: "signed in")
      end
    end

    it "shows two browsers as two device rows, last signed in first" do
      device(browser: "Firefox", os: "Linux", last_signed_in_at: Time.now - 600)
      device(last_signed_in_at: Time.now - 60)
      get "/admin/settings/security"

      expect(titles).to eq(["Safari · iOS", "Firefox · Linux"])
    end

    it "offers to sign out a signed-in device", :aggregate_failures do
      phone = device(last_signed_in_at: Time.now - 60)
      get "/admin/settings/security"
      form = rows.first.find("form[action='/admin/settings/security/devices/#{phone}/sign-out']")

      expect(form["data-confirm"]).to eq(confirm_sign_out("Safari · iOS"))
      expect(form).to have_button("Sign out", class: "warn")
    end

    it "pills a signed-out device and offers no sign-out", :aggregate_failures do
      device(last_signed_in_at: Time.now - 60, signed_out_at: Time.now)
      get "/admin/settings/security"

      expect(rows.first).to have_css(".pill:not(.green)", exact_text: "signed out")
      expect(rows.first).to have_no_css("form")
    end

    it "pills a device signed in again after a sign-out as signed in" do
      device(last_signed_in_at: Time.now, signed_out_at: Time.now - 60)
      get "/admin/settings/security"

      expect(rows.first).to have_css(".pill.green", exact_text: "signed in").and have_css("form")
    end

    describe "signing out a device" do
      let!(:phone) { device(last_signed_in_at: Time.now - 60) }

      before { admin_post "/admin/settings/security/devices/#{phone}/sign-out" }

      it "stamps the device signed out and comes back to the tab", :aggregate_failures do
        expect(last_response.location).to eq("/admin/settings/security")
        expect(database[:devices].where(id: phone).get(:signed_out_at)).to be_within(2).of(Time.now)
      end

      it "says so" do
        follow_redirect!

        expect(page).to have_text(Admin::Slice["i18n"].t("security_page.toasts.signed_out"))
      end
    end

    it "returns 404 for a device ID that is no ID" do
      admin_post "/admin/settings/security/devices/not-an-id/sign-out"

      expect(last_response).to be_not_found
    end

    it "lists a device's failed sign-in beside it" do
      phone = device(last_signed_in_at: Time.now)
      sign_in_row(device_id: phone, browser: "Safari", os: "iOS", outcome: "denied")
      get "/admin/settings/security"

      expect(rows.map { it.find(".pill").text }).to eq(["signed in", "denied"])
    end

    it "names a device whose sign-ins were pruned" do
      device(browser: nil, os: nil, last_signed_in_at: Time.now - (100 * 24 * 60 * 60))
      get "/admin/settings/security"

      expect(rows.first).to have_text("Unknown device").and have_text("Unknown place")
    end

    it "lists sign-ins newest first" do
      sign_in_row(browser: "Safari", created_at: Time.now - 60)
      sign_in_row(browser: "Firefox", outcome: "wrong_account")
      get "/admin/settings/security"

      expect(titles).to eq(["Firefox · macOS", "Safari · macOS"])
    end

    describe "paging sign-ins" do
      def browsers = titles.map { it.split(" · ").first }

      before do
        lower_page_size(:admin, to: 2)
        %w[Safari Edge Firefox].each_with_index do |browser, index|
          sign_in_row(browser:, created_at: Time.now - (60 * (3 - index)))
        end
      end

      it "shows the newest page and links to older sign-ins", :aggregate_failures do
        get "/admin/settings/security"

        expect(browsers).to eq(%w[Firefox Edge])
        expect(card("Sign-ins")).to have_css("nav.pager a[rel='next'][href='/admin/settings/security?page=2']")
      end

      it "shows older sign-ins on a later page", :aggregate_failures do
        get "/admin/settings/security", page: "2"

        expect(browsers).to eq(%w[Safari])
        expect(card("Sign-ins")).to have_css("nav.pager a[rel='prev'][href='/admin/settings/security']")
      end

      it "returns 404 for a page past the end" do
        get "/admin/settings/security", page: "3"

        expect(last_response).to be_not_found
      end
    end

    it "shows each sign-in's outcome, place, address and time" do
      sign_in_row(outcome: "wrong_account", address: "203.0.113.9", city: "Paris", country: "FR")
      get "/admin/settings/security"

      expect(rows.first).to have_text("wrong account").and have_text("Paris · FR · 203.0.113.9")
        .and have_css("time")
    end

    it "names the provider each sign-in went through" do
      sign_in_row(provider: "google")
      get "/admin/settings/security"

      expect(rows.first).to have_text("Google · London · GB · 81.2.69.160")
    end

    it "names the provider that failed" do
      sign_in_row(provider: "google", outcome: "provider_failed")
      get "/admin/settings/security"

      expect(rows.first).to have_css(".pill.pink", exact_text: "Google failed")
    end

    it "pills a sign-in green when it went through and pink when it did not", :aggregate_failures do
      sign_in_row(browser: "Safari", created_at: Time.now - 60)
      sign_in_row(browser: "Firefox", outcome: "denied")
      get "/admin/settings/security"

      expect(card("Sign-ins").find(".li", text: "Safari")).to have_css(".pill.green", exact_text: "signed in")
      expect(card("Sign-ins").find(".li", text: "Firefox")).to have_css(".pill.pink", exact_text: "denied")
    end

    it "shows a sign-in's country by name when it has one" do
      sign_in_row(country_name: "United Kingdom")
      get "/admin/settings/security"

      expect(rows.first).to have_text("London · United Kingdom · 81.2.69.160")
    end

    it "names a device and place it could not read" do
      sign_in_row(browser: nil, os: nil, city: nil, country: nil)
      get "/admin/settings/security"

      expect(rows.first).to have_text("Unknown device").and have_text("Unknown place")
    end

    it "lists a token's sightings with place, calls, address and both times" do
      sight(api_token_id: token("Terminal").id)
      get "/admin/settings/security"

      expect(credential("Terminal").find(".li")).to have_css(".li-title", text: "Firefox · Linux")
        .and have_text("London · GB · 3 calls · 81.2.69.160").and have_text("first seen").and have_text("last seen")
        .and have_css("time", count: 2)
    end

    it "shows a sighting's country by name when it has one" do
      sight(api_token_id: token("Terminal").id, country_name: "United Kingdom")
      get "/admin/settings/security"

      expect(credential("Terminal").find(".li")).to have_text("London · United Kingdom · 3 calls")
    end

    it "names a sighting's device and place it could not read" do
      sight(api_token_id: token("Terminal").id, browser: nil, os: nil, city: nil, country: nil)
      get "/admin/settings/security"

      expect(credential("Terminal").find(".li")).to have_text("Unknown device").and have_text("Unknown place")
    end

    it "lists an MCP client's sightings under that client" do
      found = client("Claude")
      sight(oauth_client_id: found.id, browser: "Chrome")
      sight(api_token_id: token("Terminal").id)
      get "/admin/settings/security"

      expect(credential("Claude").all(".li-title").map(&:text)).to eq(["Chrome · Linux"])
    end

    it "names a client that registered no name by its redirect host" do
      client(nil)
      get "/admin/settings/security"

      expect(page.find(".security-cred-name")).to have_text(/\Aclaude\.ai/)
    end

    it "shows a credential nothing has used" do
      token("Terminal")
      get "/admin/settings/security"

      expect(credential("Terminal")).to have_css(".empty")
    end

    it "links to the Honeybadger project when one is set" do
      allow(Hanami.app.settings).to receive(:honeybadger).and_return(project_url: "https://app.honeybadger.io/projects/1")
      get "/admin/settings/security"

      expect(page).to have_link("Errors on Honeybadger", href: "https://app.honeybadger.io/projects/1")
    end

    it "leaves the Honeybadger link out when no project is set" do
      get "/admin/settings/security"

      expect(page).to have_no_link("Errors on Honeybadger")
    end

    it "shows in the navigation" do
      get "/admin/settings/security"

      expect(page).to have_css("[data-palette-href='/admin/settings/security']", visible: :all)
    end
  end
end

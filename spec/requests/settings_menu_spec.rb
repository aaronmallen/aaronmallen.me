# frozen_string_literal: true

RSpec.describe "Settings menu", type: :request do
  let(:admin_items) do
    "[role='group'] + hr.settings-menu-separator + a.settings-menu-option[href='/admin'] + " \
      "form[action='/admin/sign-out'][method='post'] button.settings-menu-option[type='submit']"
  end

  def page = Capybara.string(last_response.body)

  def panel = page.find_by_id("settings-menu", visible: :all)

  def sign_out_from_menu(path, return_to: nil)
    get path
    form = panel.find("form[action='/admin/sign-out']", visible: :all)
    fields = form.all("input[type='hidden']", visible: :all).to_h { [it[:name], it.value] }
    fields["return_to"] = return_to if return_to
    post "/admin/sign-out", fields
  end

  describe "signed out" do
    %w[/ /about /contact /projects /writing].each do |path|
      it "links nowhere in the admin on #{path}" do
        get path

        expect(page).to have_no_css("a[href^='/admin'], form[action^='/admin']", visible: :all)
      end
    end

    it "shows only the theme options", :aggregate_failures do
      get "/"

      expect(panel).to have_css(".settings-menu-option", count: 2, visible: :all)
      expect(panel).to have_no_css(".settings-menu-separator", visible: :all)
    end

    it "tells the theme picker which cookie to set" do
      get "/"

      expect(page).to have_css("html[data-theme-cookie='site_theme']", visible: :all)
    end

    it "shows only the theme options with a forged session cookie", :aggregate_failures do
      set_cookie "#{Blog::SessionCookie::KEY}=forged"
      get "/"

      expect(last_response).to be_ok
      expect(panel).to have_css(".settings-menu-option", count: 2, visible: :all)
    end
  end

  describe "signed in" do
    before do
      sign_in_to_admin
      get "/admin"
    end

    it "shows Admin and Sign out below the theme options" do
      get "/about"

      expect(panel).to have_css(admin_items, visible: :all)
    end

    it "labels the items from translations", :aggregate_failures do
      get "/about"

      expect(panel).to have_link("Admin", href: "/admin", visible: :all)
      expect(panel).to have_button("Sign out", visible: :all)
    end

    it "sets no cookie on a public page" do
      get "/about"

      expect(last_response.headers["set-cookie"]).to be_nil
    end

    it "hides the items once the session is older than 30 days" do
      allow(Time).to receive(:now).and_return(Time.now + (30 * 24 * 60 * 60))
      get "/about"

      expect(panel).to have_no_css(".settings-menu-separator", visible: :all)
    end
  end

  describe "signing out from the menu" do
    before do
      sign_in_to_admin
      get "/admin"
    end

    it "returns to the page I was on" do
      sign_out_from_menu("/about?ref=menu")

      expect(last_response.location).to eq("/about?ref=menu")
    end

    it "ends the session", :aggregate_failures do
      sign_out_from_menu("/about")
      follow_redirect!

      expect(panel).to have_no_css(".settings-menu-separator", visible: :all)
      get "/admin"
      expect(last_response.location).to end_with("/admin/sign-in")
    end

    it "sends me home from an admin page rather than back to sign-in" do
      sign_out_from_menu("/about", return_to: "/admin")

      expect(last_response.location).to eq("/")
    end

    [
      "//evil.example",
      "/\\evil.example",
      "https://evil.example/about",
      "about",
      "/about\r\nLocation: https://evil.example",
      "/admin/posts",
    ].each do |return_to|
      it "sends me home instead of to #{return_to.inspect}" do
        sign_out_from_menu("/about", return_to:)

        expect(last_response.location).to eq("/")
      end
    end
  end
end

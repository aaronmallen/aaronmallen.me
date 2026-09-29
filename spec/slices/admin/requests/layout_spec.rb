# frozen_string_literal: true

RSpec.describe "Admin layout", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  describe "signed in" do
    before do
      sign_in_to_admin
      get "/admin"
    end

    it "renders the public header" do
      expect(page).to have_css("header.site-header nav.main-nav")
    end

    it "renders the context bar after the header" do
      expect(page).to have_css("header.site-header + .ctx-bar .ctx-bar-content")
    end

    it "titles today's page Today, not with the date in its heading" do
      expect(page).to have_title("Today | Admin | #{Blog::Owner.full_name}")
    end

    it "renders the page head in the page" do
      expect(page).to have_css("main#main .page-head h1", text: Blog::TimeZone.today.strftime("%A, %B %-d"))
    end

    it "renders sign out as a submit button in the page head" do
      expect(page).to have_css(".page-head-actions form button.btn[type='submit']", text: "Sign out")
    end

    it "says today is where you are" do
      expect(page).to have_css(".ctx-where", text: %r{Daily\s+/\s+today})
    end

    it "renders the palette, and the button that opens it on a phone", :aggregate_failures do
      expect(page).to have_css("dialog#command-palette", visible: :all)
      expect(page).to have_button(class: "slash", visible: :all)
    end

    it "offers only the sections whose features exist" do
      sections = page.all("[data-palette-group]:not([aria-labelledby$='-actions']) [data-palette-option]")

      expect(sections.map { it["data-palette-href"] })
        .to eq(%w[/admin /admin/tasks /admin/journal /admin/posts /admin/social /admin/projects /admin/messages
                  /admin/webmentions /admin/activity /admin/analytics /admin/tags /admin/clients])
    end

    it "reads the session validity row once for the action and the layout" do
      reads = counting { get "/admin" }.grep(/session_validity/)

      expect(reads).to have(1).item
    end

    it "links no feed" do
      expect(page).to have_no_css("head link[rel='alternate']", visible: :all)
    end

    it "shows the app version in the footer as plain text", :aggregate_failures do
      expect(page).to have_css("main#main ~ footer.adm-footer", text: "Version #{Blog::Version::CURRENT}")
      expect(page).to have_no_css("footer.adm-footer a")
    end

    it "loads the site styles and scripts", :aggregate_failures do
      expect(page).to have_css("link[rel='stylesheet'][href*='app']", visible: :all)
      expect(page).to have_css("script[src*='app']", visible: :all)
    end
  end

  describe "a failed sign-in" do
    before do
      connect_github(client_id: nil, client_secret: nil)
      get "/admin/sign-in"
    end

    it "renders the header and page head", :aggregate_failures do
      expect(page).to have_css("header.site-header")
      expect(page).to have_css(".page-head h1", text: "Sign-in failed")
    end

    it "titles the page with its heading" do
      expect(page).to have_title("Sign-in failed | Admin | #{Blog::Owner.full_name}")
    end

    it "renders no context bar and no palette", :aggregate_failures do
      expect(page).to have_no_css(".ctx-bar")
      expect(page).to have_no_css("dialog#command-palette", visible: :all)
    end

    it "shows the app version in the footer" do
      expect(page).to have_css("footer.adm-footer", text: "Version #{Blog::Version::CURRENT}")
    end

    it "offers only the theme options in the settings menu" do
      expect(page).to have_no_css("#settings-menu .settings-menu-separator", visible: :all)
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Admin layout", :frozen_clock, type: :request do
  def section_groups = "[data-palette-group]:not([aria-labelledby$='-actions']):not([aria-labelledby$='-see-all'])"

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
      expect(page).to have_title("Today | Admin | #{Hanami.app.settings.owner_name}")
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
      sections = page.all("#{section_groups} [data-palette-option]")

      expect(sections.map { it["data-palette-href"] })
        .to eq(%w[/admin /admin/tasks /admin/journal /admin/calendar /admin/decisions /admin/posts /admin/social
                  /admin/projects /admin/inbox /admin/messages /admin/webmentions /admin/activity /admin/review
                  /admin/time /admin/analytics /admin/tags /admin/people /admin/clients /admin/tokens /admin/security])
    end

    it "reads the session validity row once for the action and the layout" do
      reads = counting { get "/admin" }.grep(/session_validity/)

      expect(reads).to have(1).item
    end

    it "loads no task to draw a page that lists none" do
      reads = counting { get "/admin/posts" }.grep(/FROM "tasks"/).grep_v(/\ASELECT count\(\*\)/)

      expect(reads).to be_empty
    end

    it "points the palette at the route that searches every record" do
      expect(page).to have_css("[data-palette-search='/admin/search/palette']", visible: :all)
    end

    it "links no feed" do
      expect(page).to have_no_css("head link[rel='alternate']", visible: :all)
    end

    it "shows the app version in the footer as plain text", :aggregate_failures do
      expect(page).to have_css("main#main ~ footer.adm-footer", text: "Version #{Blog::Version::CURRENT}")
      expect(page).to have_no_css("footer.adm-footer a")
    end

    it "renders the confirm dialog before the footer and the palette after it", :aggregate_failures do
      expect(page).to have_css("main#main ~ dialog#confirm-dialog + footer.adm-footer", visible: :all)
      expect(page).to have_css("footer.adm-footer ~ dialog#command-palette", visible: :all)
    end

    it "draws the confirm dialog in the dialog shell with a foot and no head", :aggregate_failures do
      shell = "dialog#confirm-dialog.dialog[role='alertdialog'][aria-labelledby='confirm-dialog-message'][hidden]"
      expect(page).to have_css("#{shell} > .dialog-box > .dialog-foot > button[data-dialog-accept]", visible: :all)
      expect(page).to have_no_css("dialog#confirm-dialog .dialog-head", visible: :all)
    end

    it "draws the key help dialog with a head that holds its title and the close button" do
      expect(page).to have_css(
        "dialog#key-help.dialog[aria-labelledby='key-help-title'] > .dialog-box > .dialog-head " \
        "> h2#key-help-title + button[data-dialog-close][aria-label='Close']",
        visible: :all,
      )
    end

    it "draws no task-dialog class" do
      expect(page).to have_no_css("[class*='task-dialog']", visible: :all)
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
      expect(page).to have_title("Sign-in failed | Admin | #{Hanami.app.settings.owner_name}")
    end

    it "renders no context bar and no palette", :aggregate_failures do
      expect(page).to have_no_css(".ctx-bar")
      expect(page).to have_no_css("dialog#command-palette", visible: :all)
    end

    it "shows the app version in the footer" do
      expect(page).to have_css("footer.adm-footer", text: "Version #{Blog::Version::CURRENT}")
    end

    it "renders no confirm dialog" do
      expect(page).to have_no_css("dialog#confirm-dialog", visible: :all)
    end

    it "offers only the theme options in the settings menu" do
      expect(page).to have_no_css("#settings-menu .settings-menu-separator", visible: :all)
    end
  end
end

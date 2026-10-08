# frozen_string_literal: true

RSpec.describe "Admin layout", :frozen_clock, type: :request do
  def section_groups = "[data-palette-group]:not([aria-labelledby$='-actions']):not([aria-labelledby$='-see-all'])"

  let(:page) { Capybara.string(last_response.body) }
  let(:screens) do
    %w[
      /admin /admin/tasks /admin/calendar /admin/time /admin/journal /admin/decisions /admin/review /admin/posts
      /admin/social /admin/people /admin/projects /admin/inbox /admin/messages /admin/webmentions /admin/analytics
      /admin/activity /admin/search /admin/tags /admin/tasks/rules /admin/webmentions#webmention-settings
      /admin/tokens /admin/clients /admin/security
    ]
  end

  describe "signed in" do
    before do
      sign_in_to_admin
      get "/admin"
    end

    it "renders the top bar in place of the public header", :aggregate_failures do
      expect(page).to have_css("header.top-bar + main#main")
      expect(page).to have_no_css(".site-header, .ctx-bar")
    end

    it "opens the top bar with a skip link and the wordmark" do
      expect(page).to have_css("header.top-bar > a.top-bar-skip[href='#main'] + a.wordmark[href='/']")
    end

    it "shows the six pills" do
      expect(page.all("nav.pill-nav a.pill-nav-link").map(&:text)).to eq(%w[Today Tasks Journal Publish Inbox Insights])
    end

    it "links each pill to its first screen" do
      expect(page.all("a.pill-nav-link").map { it["href"] })
        .to eq(%w[/admin /admin/tasks /admin/journal /admin/posts /admin/inbox /admin/analytics])
    end

    it "marks today current" do
      expect(page).to have_css("a.pill-nav-link[aria-current='page']", count: 1, text: "Today")
    end

    it "opens the palette from the search button on the slash key" do
      expect(page).to have_css("button.top-bar-search[data-palette-open][data-key='/']")
    end

    it "opens the avatar menu from the avatar" do
      expect(page).to have_css("button.avatar[popovertarget='avatar-menu'] + #avatar-menu[popover]", visible: :all)
    end

    it "links the site and every settings tab from the avatar menu" do
      expect(page.all("#avatar-menu a.avatar-menu-item", visible: :all).map { it["href"] })
        .to eq(%w[/writing /about /projects /contact /admin/tags /admin/tasks/rules
                  /admin/webmentions#webmention-settings /admin/tokens /admin/clients /admin/security])
    end

    it "offers the keys, the themes and sign out in the avatar menu", :aggregate_failures do
      menu = page.find_by_id("avatar-menu", visible: :all)

      expect(menu).to have_css("button.avatar-menu-item[data-key='?'][data-key-help-open]", visible: :all)
      expect(menu).to have_css("button.avatar-menu-item[data-theme-choice]", count: 2, visible: :all)
      expect(menu).to have_css("form[action='/admin/sign-out'] button.avatar-menu-item[type='submit']", visible: :all)
    end

    it "shows no screen-tabs on today" do
      expect(page).to have_no_css(".screen-tabs")
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

    it "renders the palette and no slash button", :aggregate_failures do
      expect(page).to have_css("dialog#command-palette", visible: :all)
      expect(page).to have_no_button(class: "slash", visible: :all)
    end

    it "offers only the sections whose features exist" do
      sections = page.all("#{section_groups} [data-palette-option]")

      expect(sections.map { it["data-palette-href"] }).to eq(screens)
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

  describe "a screen under a pill" do
    before do
      sign_in_to_admin
      get "/admin/inbox"
    end

    it "marks its pill current" do
      expect(page).to have_css("a.pill-nav-link[aria-current='page']", count: 1, text: "Inbox")
    end

    it "lists the pill's screens as screen-tabs under the page head", :aggregate_failures do
      tabs = page.all(".page-head + .screen-tabs a.screen-tab")

      expect(tabs.map { it["href"] }).to eq(%w[/admin/inbox /admin/messages /admin/webmentions])
      expect(page).to have_css("a.screen-tab[aria-current='page']", count: 1, text: "waiting")
    end
  end

  describe "a settings screen" do
    before do
      sign_in_to_admin
      get "/admin/tasks/rules"
    end

    it "marks no pill current" do
      expect(page).to have_no_css("a.pill-nav-link[aria-current]")
    end

    it "lists the settings tabs as screen-tabs", :aggregate_failures do
      expect(page.all("a.screen-tab").map(&:text))
        .to eq(["tags", "task rules", "webmentions", "API tokens", "MCP clients", "security"])
      expect(page).to have_css("a.screen-tab[aria-current='page']", text: "task rules")
    end
  end

  describe "an address nothing lives at" do
    before do
      sign_in_to_admin
      get "/admin/nowhere"
    end

    it "answers 404 in the admin layout", :aggregate_failures do
      expect(last_response.status).to eq(404)
      expect(page).to have_css("header.top-bar + main#main .page-head h1", text: "Page not found")
      expect(page).to have_css("footer.adm-footer", text: "Version #{Blog::Version::CURRENT}")
    end
  end

  describe "a failed sign-in" do
    before do
      connect_github(client_id: nil, client_secret: nil)
      get "/admin/sign-in"
    end

    it "renders the top bar and page head", :aggregate_failures do
      expect(page).to have_css("header.top-bar a.wordmark")
      expect(page).to have_css(".page-head h1", text: "Sign-in failed")
    end

    it "titles the page with its heading" do
      expect(page).to have_title("Sign-in failed | Admin | #{Hanami.app.settings.owner_name}")
    end

    it "renders no pills, no avatar menu and no palette", :aggregate_failures do
      expect(page).to have_no_css(".pill-nav, #avatar-menu", visible: :all)
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

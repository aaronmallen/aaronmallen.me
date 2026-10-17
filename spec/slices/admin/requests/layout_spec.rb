# frozen_string_literal: true

RSpec.describe "Admin layout", :frozen_clock, type: :request do
  def section_groups = "[data-palette-group]:not([aria-labelledby$='-actions']):not([aria-labelledby$='-see-all'])"

  let(:page) { Capybara.string(last_response.body) }
  let(:screens) do
    %w[
      /admin /admin/tasks /admin/calendar /admin/projects /admin/journal /admin/decisions /admin/review /admin/posts
      /admin/social /admin/files /admin/links /admin/inbox /admin/mail /admin/webmentions /admin/analytics
      /admin/activity /admin/health /admin/time /admin/tags /admin/people
      /admin/tasks/rules /admin/webmentions/settings /admin/tokens /admin/services /admin/clients /admin/security
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
        .to eq(%w[/writing /about /projects /contact /admin/tags /admin/people /admin/tasks/rules
                  /admin/webmentions/settings /admin/tokens /admin/services /admin/clients /admin/security])
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

    it "renders the page head in the page, with the date in its kicker", :aggregate_failures do
      expect(page).to have_css("main#main .page-head h1", text: Admin::Slice["i18n"].t("ui.views.today.show.headline.empty"))
      expect(page).to have_css("main#main .page-head-kicker", text: Blog::TimeZone.today.strftime("%A, %B %-d"))
    end

    it "renders sign out as a submit button in the avatar menu, not in the page", :aggregate_failures do
      expect(page).to have_css("#avatar-menu form button[type='submit']", text: "Sign out", visible: :all)
      expect(page).to have_no_css("main form[action='/admin/sign-out']", visible: :all)
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

    it "reads the owner identities once for the action and the layout" do
      reads = counting { get "/admin" }.grep(/owner_identities/)

      expect(reads).to have(1).item
    end

    it "loads no task to draw a page that lists none" do
      reads = counting { get "/admin/posts" }.grep(/FROM "tasks"/).grep_v(/\ASELECT (\(SELECT )?count\(\*\)/)

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

    it "renders the confirm template before the footer and the palette after it", :aggregate_failures do
      expect(page).to have_css("main#main ~ template[data-confirm-template] + footer.adm-footer", visible: :all)
      expect(page).to have_css("footer.adm-footer ~ dialog#command-palette", visible: :all)
    end

    it "marks the key help a modal dialog with its rows in a body of their own" do
      shell = "dialog#key-help.dialog.modal[role='dialog'][aria-modal='true']"
      expect(page).to have_css("#{shell} > .dialog-box > .dialog-head + .dialog-body > dl.keys", visible: :all)
    end

    it "draws the key help dialog with a head that holds its title and the close button" do
      expect(page).to have_css(
        "dialog#key-help.dialog[aria-labelledby='key-help-title'] > .dialog-box > .dialog-head " \
        "> h2#key-help-title + button[data-dialog-close][aria-label='Close']",
        visible: :all,
      )
    end

    it "hooks every dialog shell for the dialog script", :aggregate_failures do
      expect(page).to have_no_css("dialog.dialog:not([data-dialog])", visible: :all)
      expect(page).to have_css("dialog#key-help[data-dialog]:not([data-dialog='static'])", visible: :all)
      expect(page).to have_css("dialog#task-create[data-dialog='static']", visible: :all)
      expect(page).to have_css("dialog#journal-write[data-dialog='static']", visible: :all)
    end

    it "tells screen readers that every dialog trigger opens a dialog", :aggregate_failures do
      expect(page).to have_css("[data-dialog-open='key-help'][aria-haspopup='dialog']", visible: :all)
      expect(page).to have_no_css("[data-dialog-open]:not([aria-haspopup='dialog'])", visible: :all)
    end

    it "draws the task panel in the dialog shell with its own label and body hook", :aggregate_failures do
      shell = "dialog#task-panel.dialog.wide.task-panel[data-dialog][data-task-panel][aria-modal='true']"
      expect(page).to have_css(
        "#{shell}[aria-label] > .dialog-box > .dialog-body[tabindex='-1'][data-task-panel-body]:empty", visible: :all,
      )
      expect(page).to have_no_css("dialog#task-panel[aria-labelledby]", visible: :all)
    end

    it "draws no task-dialog class" do
      expect(page).to have_no_css("[class*='task-dialog']", visible: :all)
    end

    it "loads the site styles and scripts", :aggregate_failures do
      expect(page).to have_css("link[rel='stylesheet'][href*='app']", visible: :all)
      expect(page).to have_css("script[src*='app']", visible: :all)
    end
  end

  describe "the reads behind it" do
    def statements(pattern) = counting { get "/admin/tokens" }.grep(pattern)

    before { sign_in_to_admin }

    it "counts the inbox in one statement" do
      expect(statements(/FROM "(mail_threads|webmentions|task_sources)"/)).to contain_exactly(
        a_string_including('FROM "mail_threads"', 'FROM "webmentions"', 'FROM "task_sources"'),
      )
    end

    it "leaves the projects to the task dialog" do
      expect(statements(/FROM "projects"/)).to be_empty
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

      expect(tabs.map { it["href"] }).to eq(%w[/admin/inbox /admin/mail /admin/webmentions])
      expect(tabs.map(&:text)).to eq(%w[waiting mail mentions])
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
        .to eq(["tags", "people", "task rules", "webmentions", "API tokens", "connected services", "MCP clients",
                "security"])
      expect(page).to have_css("a.screen-tab[aria-current='page']", text: "task rules")
    end

    {
      "/admin/tags" => "Tags", "/admin/tasks/rules" => "Task rules", "/admin/tokens" => "API tokens",
      "/admin/webmentions/settings" => "Webmentions", "/admin/services" => "Connected services",
      "/admin/clients" => "MCP clients", "/admin/security" => "Security",
    }.each do |route, title|
      it "heads #{route} as Settings and titles it #{title}", :aggregate_failures do
        get route

        expect(page).to have_css(".page-head h1", exact_text: "Settings")
        expect(page).to have_title("#{title} | Admin | #{Hanami.app.settings.owner_name}")
      end
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
      post "/admin/sign-in/github", _csrf_token: admin_csrf_token
    end

    it "renders the site header and page head", :aggregate_failures do
      expect(page).to have_css("header.site-header + main#main .page-head h1", text: "Sign-in failed")
      expect(page).to have_no_css("header.top-bar")
    end

    it "links the site pages from the header" do
      expect(page.all("nav.main-nav a.main-nav-link").map { it["href"] }).to eq(%w[/writing /about /projects /contact])
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

    it "renders no confirm template" do
      expect(page).to have_no_css("template[data-confirm-template]", visible: :all)
    end

    it "offers the theme toggle in place of the settings menu", :aggregate_failures do
      expect(page).to have_css(".main-nav-settings button[data-theme-toggle]")
      expect(page).to have_no_css("#settings-menu", visible: :all)
    end
  end
end

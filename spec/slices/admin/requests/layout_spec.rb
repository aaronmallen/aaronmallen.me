# frozen_string_literal: true

RSpec.describe "Admin layout", :frozen_clock, type: :request do
  def section_groups = "[data-palette-group]:not([aria-labelledby$='-actions']):not([aria-labelledby$='-see-all'])"

  def switcher_sides
    page.all("#nav-switcher > .switcher-side", visible: :all).map do |side|
      side.all(".switcher-column", visible: :all).map do |column|
        column.first(".switcher-heading, .switcher-row", visible: :all).text(:all).strip
      end
    end
  end

  let(:page) { Capybara.string(last_response.body) }
  let(:screens) do
    %w[
      /admin /admin/inbox /admin/mail /admin/webmentions /admin/tasks /admin/calendar /admin/projects /admin/journal
      /admin/decisions /admin/review /admin/posts /admin/social /admin/files /admin/links /admin/agents/memories
      /admin/agents/artifacts /admin/agents/sessions /admin/analytics /admin/activity /admin/health /admin/time
      /admin/settings/webmentions /admin/settings/tagging /admin/settings/services /admin/settings/security
      /admin/settings/jobs
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

    it "shows the seven pills" do
      expect(page.all("nav.pill-nav a.pill-nav-link").map(&:text))
        .to eq(%w[Today Inbox Tasks Journal Publish Agents Insights])
    end

    it "links each pill to its first screen" do
      expect(page.all("a.pill-nav-link").map { it["href"] })
        .to eq(%w[/admin /admin/inbox /admin/tasks /admin/journal /admin/posts /admin/agents/memories
                  /admin/analytics])
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

    it "opens the switcher panel from its button" do
      expect(page).to have_css(".switcher[popovertarget='nav-switcher'] + #nav-switcher[popover]", visible: :all)
    end

    it "lists every screen but settings in the switcher, grouped" do
      rows = page.all("#nav-switcher a.switcher-row", visible: :all).map { it["href"] }

      expect(rows).to match_array(screens.grep_v(%r{\A/admin/settings/}))
    end

    it "deals the switcher groups to a left and a right side in turn" do
      expect(switcher_sides).to eq([%w[today Tasks Publish Insights], %w[Inbox Journal Agents]])
    end

    it "marks today current in the switcher", :aggregate_failures do
      expect(page).to have_css("#nav-switcher a.switcher-row[aria-current='page']", count: 1, text: "today",
                                                                                    visible: :all)
      expect(page).to have_css("button.switcher[aria-label='Navigate. Current: Today']")
    end

    it "links the site and one Settings item from the avatar menu" do
      expect(page.all("#avatar-menu a.avatar-menu-item", visible: :all).map { it["href"] })
        .to eq(%w[/writing /about /projects /contact /admin/settings])
    end

    it "marks the Settings item with a gear" do
      expect(page).to have_css("#avatar-menu a.avatar-menu-item[href='/admin/settings'] .fa-gear", visible: :all)
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
    def statements(pattern) = counting { get "/admin/settings/services" }.grep(pattern)

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
      expect(page).to have_no_css(".screen-tab-note")
      expect(page).to have_css("a.screen-tab[aria-current='page']", count: 1, text: "waiting")
    end
  end

  describe "a settings screen" do
    before do
      sign_in_to_admin
      get "/admin/settings/services"
    end

    it "marks no pill current" do
      expect(page).to have_no_css("a.pill-nav-link[aria-current]")
    end

    it "lists the settings tabs as screen-tabs", :aggregate_failures do
      expect(page.all("a.screen-tab").map { it.text.sub(/ \d+\z/, "") })
        .to eq(["tagging", "webmentions", "connected services", "jobs", "security"])
      expect(page).to have_css("a.screen-tab[aria-current='page']", text: "connected services")
    end

    {
      "/admin/settings/tagging" => "Tagging", "/admin/settings/webmentions" => "Webmentions",
      "/admin/settings/services" => "Connected services", "/admin/settings/security" => "Security",
      "/admin/settings/jobs" => "Jobs",
    }.each do |route, title|
      it "heads #{route} as Settings and titles it #{title}", :aggregate_failures do
        get route

        expect(page).to have_css(".page-head h1", exact_text: "Settings")
        expect(page).to have_title("#{title} | Admin | #{Hanami.app.settings.owner_name}")
      end

      it "shows only the Settings tab bar on #{route}" do
        get route

        expect(page).to have_css(".screen-tabs", count: 1)
      end
    end

    {
      "/admin/settings/tagging" => ["tagging", "/admin/settings/tagging"],
      "/admin/settings/webmentions" => ["webmentions", "/admin/settings/webmentions"],
      "/admin/settings/services" => ["connected services", "/admin/settings/services"],
      "/admin/settings/jobs" => ["jobs", "/admin/settings/jobs"],
    }.each do |route, (screen, href)|
      it "names Settings and #{screen} in the switcher on #{route}", :aggregate_failures do
        get route

        expect(page).to have_css("button.switcher .switcher-group", exact_text: "Settings")
        expect(page).to have_css("button.switcher .switcher-screen", exact_text: screen)
        expect(page).to have_css("[data-palette-href='#{href}']", visible: :all)
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

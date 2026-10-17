# frozen_string_literal: true

RSpec.describe "Admin pages that stay live", type: :feature do
  let(:events) { "/admin/events" }

  def caret = evaluate_script("[document.activeElement.selectionStart, document.activeElement.selectionEnd]")

  def focused?(element) = evaluate_script("document.activeElement === arguments[0]", element)

  def live(path)
    sign_in_to_admin
    visit path
    wait_for_stream
  end

  def policy
    evaluate_async_script(<<~JS)
      const done = arguments[arguments.length - 1];
      fetch(location.href).then((response) => done(response.headers.get("Content-Security-Policy")));
    JS
  end

  def sync_issues
    connect_github_token
    stub_github(GitHubGraphQL::ASSIGNED_QUERY, github_issue_search(github_issue("I_seven", number: 7, title: "Synced")))
    Tasks::Jobs::SyncIssues.new.perform("github")
  end

  def theme
    evaluate_script(<<~JS)
      document.documentElement.dataset.siteTheme ?? (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
    JS
  end

  def wait_for_stream
    Timeout.timeout(5) { sleep 0.05 until request_gate.answered(events) >= 1 }
  end

  it "updates the inbox badge when issues sync from Tasks > External", :aggregate_failures do
    live "/admin/tasks?filter=external"
    expect(page).to have_no_css(".pill-nav-dot")

    sync_issues

    expect(page).to have_css(".top-bar .pill-nav-dot")
    expect(page).to have_css("#command-palette-inbox .pal-r-sub", text: "1 waiting", visible: :all)
  end

  it "shows a new message in the open inbox" do
    live "/admin/inbox"
    message = create(:message, subject: "Hello there")

    expect(page).to have_css("#message-#{message.id}", text: "Hello there")
  end

  it "shows a new message on the mail page and keeps the open one", :aggregate_failures do
    opened = create(:message, :read, subject: "Answered")
    live "/admin/mail?thread=#{opened.id}"
    message = create(:message, subject: "Hello there")

    expect(page).to have_css("#thread-#{message.id}", text: "Hello there")
    expect(page).to have_css(".mail-reader h2", text: "Answered")
  end

  it "keeps the mail Select button on screen after a live update" do
    live "/admin/mail"
    message = create(:message, subject: "Hello there")
    find("#thread-#{message.id}")

    expect(page).to have_css("button[data-bulk-toggle][aria-pressed='false']", text: "Select")
  end

  it "marks the current theme in the avatar menu after a live update" do
    live "/admin/inbox"
    create(:message, subject: "Hello there")
    find(".top-bar .pill-nav-dot")
    click_button(class: "avatar")

    expect(page).to have_css(".avatar-menu-item[data-theme-choice='#{theme}'][aria-pressed='true']")
  end

  describe "on a decision page with an empty comment box" do
    before do
      live "/admin/decisions/#{create(:decision).id}"
      create(:message, subject: "Hello there")
      find(".top-bar .pill-nav-dot")
    end

    it "keeps the Add button hidden after a live update" do
      expect(page).to have_no_button(Admin::Slice["i18n"].t("ui.components.comment_thread.add"))
    end
  end

  describe "on the mail page after a live update" do
    before do
      connect_google(account_id: "aaron@work.example", scopes: Spec::GoogleAccounts::GMAIL_SCOPES)
      live "/admin/mail"
      click_link "Compose"
      find("#mail-compose .mail-editor-surface").send_keys(:escape)
      find("#thread-#{create(:message, subject: 'Hello there').id}")
      click_link "Compose"
    end

    it "keeps the rich editor in place of the plain box", :aggregate_failures do
      expect(page).to have_css("#mail-compose .mail-editor-surface")
      expect(page).to have_no_css("#mail-compose [data-mail-text]")
    end

    it "keeps Cc and Bcc behind their buttons", :aggregate_failures do
      expect(page).to have_button("cc")
      expect(page).to have_no_field("mail-compose-cc")
    end
  end

  it "keeps the people finder on screen after a live update" do
    connect_social_networks
    live "/admin/people"
    create(:message, subject: "Hello there")
    find(".top-bar .pill-nav-dot")

    expect(find_by_id("person-finder")).to have_field("Search Mastodon")
  end

  it "shows a new webmention in the open inbox" do
    live "/admin/inbox"
    mention = create(:webmention, author_name: "A neighbour")

    expect(page).to have_css("#webmention-#{mention.id}", text: "A neighbour")
  end

  it "shows a new sign-in on the open security page" do
    live "/admin/settings/security"
    Security::Slice["repos.sign_in_mutations"].create(
      outcome: "denied", provider: "github", address: "203.0.113.9", user_agent: "FF", browser: "Firefox", os: "Linux",
    )

    expect(page).to have_css(".li-title", text: "Firefox · Linux")
  end

  it "shows a new connection on the open services page" do
    live "/admin/services"
    Services::Slice["repos.connection_mutations"]
      .add(provider: "linear", account_id: "ws-1", label: "ROOT workspace", credentials: { api_key: "lin_api_secret" })

    expect(page).to have_css(".svc-account", text: "ROOT workspace")
  end

  it "morphs under a policy without unsafe-eval", :aggregate_failures do
    live "/admin/inbox"
    message = create(:message)

    expect(policy).to include("script-src 'self'")
    expect(policy).not_to include("unsafe-eval")
    expect(page).to have_css("#message-#{message.id}")
  end

  describe "on a page that lists its tables" do
    before { create(:sprint, sprint_date: today) }

    def notify(table) = Tasks::Slice["db.rom"].gateways[:default].connection.notify("admin_changes", payload: table)

    def renders(path = "/admin/tasks") = request_gate.count(path)

    def wait_for_renders(count, path = "/admin/tasks")
      Timeout.timeout(5) { sleep 0.05 until renders(path) >= count }
    end

    it "lists the tables behind the page and the top bar" do
      live "/admin/tasks"

      expect(find("main")["data-live-tables"].split).to include("task_tags", "mail_threads")
    end

    it "ignores a change to a table it does not list" do
      live "/admin/tasks"
      notify("decisions")
      sleep 1

      expect(renders).to eq(1)
    end

    it "refetches for a change to a table it lists" do
      live "/admin/tasks"
      notify("task_tags")

      expect { wait_for_renders(2) }.not_to raise_error
    end

    it "refetches on the catch-up event" do
      live "/admin/tasks"
      notify(Admin::Live::Hub::CATCH_UP)

      expect { wait_for_renders(2) }.not_to raise_error
    end

    it "ignores a new commit on the calendar" do
      live "/admin/calendar"
      notify("commits")
      sleep 1

      expect(renders("/admin/calendar")).to eq(1)
    end

    describe "while a refetch is in flight" do
      let(:landing) { request_gate.hold("/admin/tasks", after: true) }

      before do
        live "/admin/tasks"
        landing
        notify("task_tags")
        landing.wait_for_arrival
        2.times do
          notify("task_tags")
          sleep 1.2
        end
      end

      after { landing.release }

      it "starts no other" do
        expect(renders).to eq(2)
      end

      it "refetches once more after it lands" do
        landing.release
        wait_for_renders(3)
        sleep 1

        expect(renders).to eq(3)
      end
    end

    it "refetches the calendar for a change to its events" do
      live "/admin/calendar"
      notify("calendar_events")

      expect { wait_for_renders(2, "/admin/calendar") }.not_to raise_error
    end
  end

  describe "after an in-place submit" do
    let(:sprint) { Tasks::Slice["repos.sprint_queries"].on(today) || create(:sprint, sprint_date: today) }

    def renders = request_gate.count("/admin/tasks")

    before do
      create(:task, :in_sprint, sprint_id: sprint.id, title: "Ship it")
      live "/admin/tasks?filter=today"
      find(".task-title", exact_text: "Ship it").ancestor(".task").tap(&:hover).click_button("Start")
      assert_selector :button, "Stop"
    end

    it "renders the page once" do
      sleep 1

      expect(renders).to eq(2)
    end

    it "still shows a change made elsewhere" do
      create(:message)

      expect(page).to have_css(".top-bar .pill-nav-dot")
    end
  end

  describe "after a save from the task panel" do
    def changed_since?(at) = evaluate_script("window.changes").any? { |id, table| id > at && table == "tasks" }

    def renders = request_gate.count("/admin/tasks")

    def watch_changes
      execute_script(<<~JS)
        window.changes = [];
        new EventSource("/admin/events").addEventListener("change", (event) => window.changes.push([Number(event.lastEventId), event.data]));
      JS
      Timeout.timeout(5) { sleep 0.05 until request_gate.answered(events) >= 2 }
    end

    before do
      create(:sprint, sprint_date: today)
      create(:task, title: "Email the accountant")
      live "/admin/tasks?filter=next"
      watch_changes
      find(".task", text: "Email the accountant").find(".task-title").click
      find("dialog#task-panel[open]").click_link("Edit")
      find("dialog#task-panel[open] [data-task-edit]").fill_in("task[title]", with: "Email the bookkeeper")
      saved = Admin::Live::Clock.now
      find("dialog#task-panel[open]").click_button("Save")
      find("dialog#task-panel[open] [data-task-read] h1", exact_text: "Email the bookkeeper")
      Timeout.timeout(5) { sleep 0.05 until changed_since?(saved) }
      find("dialog#task-panel[open] [data-task-read] .task-drawer-close").click
    end

    it "reloads the page with no refetch before it", :aggregate_failures do
      expect(page).to have_css(".task-title", exact_text: "Email the bookkeeper")
      expect(renders).to eq(2)
    end
  end

  describe "while the owner types" do
    let(:mention) { create(:webmention, received_at: Time.now - 60) }
    let(:reason) { find("#webmention-#{mention.id} input[name='reason']") }

    before do
      mention
      live "/admin/inbox"
      reason.send_keys("sent from a bot")
      execute_script("document.activeElement.setSelectionRange(4, 8)")
      assert_selector "#message-#{create(:message).id}"
    end

    it "keeps focus, the caret and unsent text in the field", :aggregate_failures do
      expect(focused?(reason)).to be(true)
      expect(reason.value).to eq("sent from a bot")
      expect(caret).to eq([4, 8])
    end
  end

  describe "while a draft has unsaved edits" do
    before do
      live "/admin/posts/new"
      fill_in "Title", with: "A fresh title"
      fill_in "Body", with: "Hello there"
      execute_script("document.activeElement.blur()")
      create(:message)
      assert_selector ".top-bar .pill-nav-dot"
    end

    it "keeps every edited field", :aggregate_failures do
      expect(find_field("Title").value).to eq("A fresh title")
      expect(find_field("Body").value).to eq("Hello there")
    end

    it "keeps what the editor drew from them" do
      expect(page).to have_css("[data-editor-words]", exact_text: "2 words")
    end
  end

  describe "with social accounts a script picked" do
    let(:accounts) { %w[mastodon bluesky].map { social_account(it).id.to_s } }

    before do
      connect_social_networks
      sign_in_to_admin
      visit "/admin/social"
      execute_script("localStorage.setItem('social:accounts', arguments[0])", JSON.generate(accounts))
      visit "/admin/social"
      wait_for_stream
      create(:message)
      assert_selector ".top-bar .pill-nav-dot"
    end

    it "keeps every picked account" do
      expect(all("[data-social-target]:checked", visible: :all).map(&:value)).to match_array(accounts)
    end
  end

  describe "with rows ticked by select all" do
    before do
      %w[first second third].each_with_index { |title, index| create(:task, title:, position: index + 1) }
      live "/admin/tasks?filter=next"
      click_button "Select"
      find(".task", text: "first").find("input[name='ids[]']").check
      find("[data-bulk-all] input").check
      create(:message)
      assert_selector ".top-bar .pill-nav-dot"
    end

    it "keeps every row ticked and counts them", :aggregate_failures do
      expect(page).to have_no_css(".task input[name='ids[]']:not(:checked)")
      expect(page).to have_css("[data-bulk-count]", exact_text: "3 ticked")
    end
  end

  describe "while a dialog is open" do
    let(:message) { create(:message) }

    before do
      live "/admin/inbox"
      click_button(class: "avatar")
      find(".avatar-menu-item[data-key-help-open]").click
      message
    end

    it "waits to morph" do
      expect(page).to have_no_css("#message-#{message.id}", wait: 1)
    end

    it "morphs once the dialog closes" do
      find("dialog#key-help [data-dialog-close]").click

      expect(page).to have_css("#message-#{message.id}")
    end
  end

  describe "in a hidden tab" do
    let(:message) { create(:message) }

    def hide(hidden)
      execute_script(<<~JS, hidden)
        Object.defineProperty(document, "hidden", { configurable: true, value: arguments[0] });
        document.dispatchEvent(new Event("visibilitychange"));
      JS
    end

    def renders = request_gate.count("/admin/inbox")

    before do
      live "/admin/inbox"
      hide(true)
    end

    it "makes no request when a change arrives" do
      message
      sleep 1

      expect(renders).to eq(1)
    end

    it "refetches once it shows again", :aggregate_failures do
      message
      sleep 1
      hide(false)

      expect(page).to have_css("#message-#{message.id}")
      expect(renders).to eq(2)
    end

    it "makes no request when it shows again with nothing missed" do
      hide(false)
      sleep 1

      expect(renders).to eq(1)
    end
  end

  describe "after the stream drops" do
    let(:message) { create(:message) }
    let(:reconnect) { request_gate.hold(events) }
    let(:sockets) { [] }

    before do
      allow(Admin::Slice["live.hub"]).to receive(:open).and_wrap_original do |open, socket|
        sockets << socket
        open.call(socket)
      end
      live "/admin/inbox"
      reconnect
      sockets.each(&:close)
      reconnect.wait_for_arrival
      message
    end

    it "waits for the stream to come back" do
      expect(page).to have_no_css("#message-#{message.id}", wait: 1)
    end

    it "shows what changed while it was down" do
      reconnect.release

      expect(page).to have_css("#message-#{message.id}")
    end
  end
end

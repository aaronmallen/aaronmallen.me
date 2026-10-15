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

  it "shows a new webmention in the open inbox" do
    live "/admin/inbox"
    mention = create(:webmention, author_name: "A neighbour")

    expect(page).to have_css("#webmention-#{mention.id}", text: "A neighbour")
  end

  it "shows a new sign-in on the open security page" do
    live "/admin/security"
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
    def renders = request_gate.count("/admin/tasks")

    before do
      create(:task, title: "Email the accountant")
      live "/admin/tasks?filter=next"
      find(".task", text: "Email the accountant").find(".task-title").click
      find("dialog#task-panel[open]").click_link("Edit")
      find("dialog#task-panel[open] [data-task-edit]").fill_in("task[title]", with: "Email the bookkeeper")
      find("dialog#task-panel[open]").click_button("Save")
      find("dialog#task-panel[open] [data-task-read] h1", exact_text: "Email the bookkeeper")
      sleep 1
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

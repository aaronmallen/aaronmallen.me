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
    Tasks::Jobs::SyncIssues.new.perform
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

  it "shows a new message on the messages page and keeps the open one", :aggregate_failures do
    opened = create(:message, :read, subject: "Answered")
    live "/admin/messages?open=#{opened.id}"
    message = create(:message, subject: "Hello there")

    expect(page).to have_css("#message-#{message.id}", text: "Hello there")
    expect(page).to have_css(".msg-letter h2", text: "Answered")
  end

  it "shows a new webmention in the open inbox" do
    live "/admin/inbox"
    mention = create(:webmention, author_name: "A neighbour")

    expect(page).to have_css("#webmention-#{mention.id}", text: "A neighbour")
  end

  it "morphs under a policy without unsafe-eval", :aggregate_failures do
    live "/admin/inbox"
    message = create(:message)

    expect(policy).to include("script-src 'self'")
    expect(policy).not_to include("unsafe-eval")
    expect(page).to have_css("#message-#{message.id}")
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

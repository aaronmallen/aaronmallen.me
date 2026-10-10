# frozen_string_literal: true

require "socket"

RSpec.describe "Admin events", type: :feature do
  let(:streams) { [] }

  after { streams.each(&:close) }

  def change(table) = "event: change\ndata: #{table}\n\n"

  def changes(opened, table) = opened.map { read_until(it, change(table)) }

  def connect(cookie: admin_session_cookie)
    TCPSocket.new(page.server.host, page.server.port).tap do |socket|
      streams << socket
      socket.write(
        "GET /admin/events HTTP/1.1\r\nHost: #{page.server.host}\r\n" \
        "Cookie: #{Blog::SessionCookie::KEY}=#{cookie}\r\n\r\n",
      )
    end
  end

  def listen_in_browser
    sign_in_to_admin
    visit "/admin/inbox"
    execute_script(<<~JS)
      window.changes = [];
      const events = new EventSource("/admin/events");
      events.addEventListener("open", () => { document.body.dataset.stream = "open"; });
      events.addEventListener("change", (event) => window.changes.push(event.data));
    JS
    assert_selector "body[data-stream='open']"
  end

  def open_stream = connect.tap { read_until(it, "retry:") }

  def read_until(socket, text, seconds: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    (+"").tap do |found|
      until found.include?(text)
        left = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        unless left.positive? && socket.wait_readable(left)
          raise "no #{text.inspect} within #{seconds}s in #{found.inspect}"
        end

        found << socket.readpartial(4096)
      end
    end
  end

  def sync_issues
    connect_github_token
    stub_github(GitHubGraphQL::ASSIGNED_QUERY, github_issue_search(github_issue("I_seven", number: 7, title: "Synced")))
    Tasks::Jobs::SyncIssues.new.perform("github")
  end

  it "answers a signed in admin with an event stream" do
    expect(read_until(connect, "retry:")).to include("Content-Type: text/event-stream\r\n")
  end

  it "sends a visitor who is not signed in to sign in" do
    expect(read_until(connect(cookie: ""), "\r\n\r\n")).to match(%r{\AHTTP/1.1 302 .*^location: /admin/sign-in\r$}im)
  end

  it "tells every open stream when issues sync" do
    opened = Array.new(2) { open_stream }
    sync_issues

    expect(changes(opened, "tasks")).to all(include(change("tasks")))
  end

  it "tells every open stream about a new message" do
    opened = Array.new(2) { open_stream }
    create(:message)

    expect(changes(opened, "messages")).to all(include(change("messages")))
  end

  it "tells every open stream about a new webmention" do
    opened = Array.new(2) { open_stream }
    create(:webmention)

    expect(changes(opened, "webmentions")).to all(include(change("webmentions")))
  end

  it "serves pages while more streams are open than the server has threads" do
    6.times { open_stream }
    sign_in_to_admin
    visit "/admin/inbox"

    expect(page).to have_css("h1", text: "Inbox")
  end

  it "reaches an event source in the browser" do
    listen_in_browser
    create(:message)

    expect { evaluate_script("window.changes") }.to eventually(include("messages"))
  end
end

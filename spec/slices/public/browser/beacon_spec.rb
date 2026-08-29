# frozen_string_literal: true

require "timeout"

RSpec.describe "Analytics beacon", type: :feature do
  let(:event_repo) { Analytics::Slice["repos.analytics_event_repo"] }

  def events = event_repo.analytics_events.order(:occurred_at, :id).to_a

  def fire(name)
    evaluate_script(<<~JS)
      (() => {
        dispatchEvent(new PageTransitionEvent("#{name}", { persisted: true }));
        return true;
      })()
    JS
  end

  def leave_page = fire("pagehide")

  def pulses = request_gate.count("/pulse")

  def pulses_through_restore
    visit "/writing"
    recorded("/writing")
    request_gate.reset
    restore
    wait_for { pulses == 1 }
  end

  def read_time(path)
    wait_for { events.find { it.path == path && it.read_seconds.positive? } }
  end

  def recorded(path) = wait_for { events.find { it.path == path } }

  def restore
    leave_page
    fire("pageshow")
  end

  def visit_both_pages
    visit "/writing"
    recorded("/writing")
    visit "/about"
    recorded("/about")
  end

  def visit_from(referrer, path:)
    visit "about:blank"
    page.driver.browser.page.command(
      "Page.navigate",
      wait: 5,
      url: "#{page.server.base_url}#{path}",
      referrer:,
      referrerPolicy: "unsafeUrl",
    )
  end

  def wait_for
    Timeout.timeout(5) do
      loop do
        found = yield
        return found if found

        sleep 0.05
      end
    end
  end

  it "stores one view when a public page loads" do
    visit "/writing"

    expect(wait_for { events.first }).to have_attributes(path: "/writing", read_seconds: 0)
  end

  it "stores the title of the page" do
    visit "/writing"

    expect(wait_for { events.first }.title).to eq(page.title)
  end

  it "sends only the origin of a referrer too long to store" do
    visit_from("https://news.example/#{'a' * 2100}", path: "/writing")

    expect(recorded("/writing")).to have_attributes(referrer_host: "news.example")
  end

  it "stores the read time when the page is left" do
    visit_both_pages

    expect(read_time("/writing").read_seconds).to be >= 1
  end

  it "sends a read again once the page is restored and left a second time" do
    pulses_through_restore
    leave_page

    expect(wait_for { pulses == 2 }).to be_truthy
  end

  it "stores one event for each page and no more" do
    visit_both_pages
    read_time("/writing")

    expect(events.map(&:path)).to eq(["/writing", "/about"])
  end

  it "sets no cookie" do
    visit "/writing"
    wait_for { events.first }

    expect(evaluate_script("document.cookie")).to be_empty
  end

  it "stays off the admin" do
    sign_in_to_admin
    visit "/admin"

    expect(evaluate_script("document.body.dataset.beacon")).to be_nil
  end

  it "records nothing while the admin signs in" do
    sign_in_to_admin
    visit "/writing"
    wait_for { request_gate.answered("/pulse") == 1 }

    expect(events).to be_empty
  end
end

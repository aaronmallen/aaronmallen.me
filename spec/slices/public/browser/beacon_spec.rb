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

  it "stores the ref of a tagged link as the source, apart from the path" do
    visit "/writing?ref=reddit"

    expect(recorded("/writing")).to have_attributes(path: "/writing", source: "reddit")
  end

  it "stores no source for a ref that is no plain token" do
    visit "/about?ref=%20"

    expect(recorded("/about").source).to be_nil
  end

  it "sends only the origin of a referrer too long to store" do
    visit_from("https://news.example/#{'a' * 2100}", path: "/writing")

    expect(recorded("/writing")).to have_attributes(referrer_host: "news.example")
  end

  it "stores the path of the page on the site that linked to this one", :aggregate_failures do
    visit_from("#{page.server.base_url}/writing?ref=reddit", path: "/about")

    expect(recorded("/about")).to have_attributes(referrer_path: "/writing", referrer_host: nil)
  end

  it "stores only the host of a referrer on another site", :aggregate_failures do
    visit_from("https://news.example/item?id=1", path: "/about")

    expect(recorded("/about")).to have_attributes(referrer_host: "news.example", referrer_path: nil)
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

  describe "scroll depth" do
    before { create(:post, :published, slug: "long", body: Faker::Lorem.paragraphs(number: 200).join("\n\n")) }

    def depth = recorded("/writing/long").scroll_depth

    def scroll_through(*shares)
      evaluate_async_script(<<~JS, shares)
        const [shares, done] = arguments;
        const sent = [];
        const sendBeacon = navigator.sendBeacon.bind(navigator);
        navigator.sendBeacon = (url, body) => {
          body.text().then((text) => sent.push(JSON.parse(text).scroll_depth));
          return sendBeacon(url, body);
        };
        const frame = () => new Promise((settled) => requestAnimationFrame(() => requestAnimationFrame(settled)));
        const height = () => document.documentElement.scrollHeight - innerHeight;
        (async () => {
          for (const share of shares) {
            scrollTo(0, height() * share);
            await frame();
          }
          done(sent);
        })();
      JS
    end

    it "starts a long page at no depth" do
      visit "/writing/long"

      expect(depth).to eq(0)
    end

    it "starts a page that fits on screen at the full depth" do
      create(:post, :published, slug: "short", body: "Short")
      visit "/writing/short"

      expect(recorded("/writing/short").scroll_depth).to eq(100)
    end

    it "stores the deepest depth the reader reached" do
      visit "/writing/long"
      recorded("/writing/long")
      scroll_through(1)

      expect(wait_for { depth == 100 }).to be(true)
    end

    it "sends each depth once it is reached and never a shallower one later" do
      visit "/writing/long"
      recorded("/writing/long")

      expect(scroll_through(0.6, 1, 0, 0.6)).to eq([50, 100])
    end
  end

  describe "clicks" do
    before do
      create(:post, :published, slug: "links",
                                body: "[the guide](https://docs.example/guide?token=secret#top) [about me](/about)")
    end

    def clicks = event_repo.analytics_clicks.to_a

    def follow(text, on: "/writing/links")
      visit on
      recorded(on)
      watch_beacon
      click_link text
      sent
    end

    def follow_injected(on:, button: 0, type: "click")
      visit on
      recorded(on)
      watch_beacon
      execute_script(<<~JS, type, button)
        const [type, button] = arguments;
        const link = document.createElement("a");
        link.href = "https://docs.example/guide";
        link.textContent = "Injected";
        document.querySelector("main").append(link);
        link.dispatchEvent(new MouseEvent(type, { bubbles: true, cancelable: true, button }));
      JS
      sent
    end

    def sent
      evaluate_async_script(<<~JS)
        const done = arguments[arguments.length - 1];
        Promise.all(window.beaconSent).then((texts) => done(texts.map((text) => JSON.parse(text))));
      JS
    end

    def watch_beacon
      execute_script(<<~JS)
        window.beaconSent = [];
        const sendBeacon = navigator.sendBeacon.bind(navigator);
        navigator.sendBeacon = (url, body) => {
          window.beaconSent.push(body.text());
          return sendBeacon(url, body);
        };
        document.addEventListener("click", (event) => event.preventDefault(), { capture: true });
      JS
    end

    it "sends the host and path of a link to another site, and nothing more" do
      expect(follow("the guide").map { it.slice("kind", "link_host", "link_path") })
        .to eq([{ "kind" => "click", "link_host" => "docs.example", "link_path" => "/guide" }])
    end

    it "stores the click against the view" do
      follow("the guide")

      expect(wait_for { clicks.first }.to_h.values_at(:event_id, :link_host, :link_path))
        .to eq([recorded("/writing/links").id, "docs.example", "/guide"])
    end

    it "sends a click opened with the middle button" do
      expect(follow_injected(on: "/writing/links", type: "auxclick", button: 1).map { it["kind"] }).to eq(["click"])
    end

    it "sends nothing for a link within the site" do
      expect(follow("about me")).to be_empty
    end

    it "sends nothing for a link to another site on a page that is not a post" do
      expect(follow_injected(on: "/about")).to be_empty
    end
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

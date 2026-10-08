# frozen_string_literal: true

require "digest"

RSpec.describe "Visits", type: :request do
  let(:address) { "203.0.113.7" }
  let(:agent) { "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36" }
  let(:event_repo) { Analytics::Slice["repos.analytics_event_mutations"] }
  let(:loopback) { "127.0.0.1" }

  before { create(:post, :published, slug: "hello", title: "Hello", tags: %w[ruby]) }

  def assets
    page = Capybara.string(last_response.body)
    sources = page.all("script[src]", visible: :all).map { it[:src] }

    sources + page.all("link[rel='stylesheet']", visible: :all).map { it[:href] }
  end

  def beacon(visit, agent: self.agent, headers: {})
    post "/pulse", visit.to_json, "CONTENT_TYPE" => "application/json",
                                  "HTTP_USER_AGENT" => agent.to_s,
                                  "REMOTE_ADDR" => address,
                                  **headers
  end

  def forged(claimed, agent: self.agent)
    post(
      "/pulse",
      { kind: "view", path: "/writing/hello", title: "Hello" }.to_json,
      "CONTENT_TYPE" => "application/json",
      "HTTP_USER_AGENT" => agent.to_s,
      "HTTP_X_FORWARDED_FOR" => claimed,
      "REMOTE_ADDR" => loopback,
    )
  end

  def month = Date.new(Blog::TimeZone.today.year, Blog::TimeZone.today.month, 1)

  def read(seconds, name: "first", path: "/writing/hello", **)
    beacon({ kind: "read", path:, read_seconds: seconds, view_token: token(name) }, **)
  end

  def roll_up_tomorrow
    allow(Time).to receive(:now).and_return(days_ahead(1))
    Analytics::Jobs::RollUpAnalytics.new.perform
  end

  def scroll(depth, name: "first", **)
    beacon({ kind: "scroll", path: "/writing/hello", scroll_depth: depth, view_token: token(name) }, **)
  end

  def stored = event_repo.analytics_events.order(:occurred_at, :id).to_a

  describe "a view" do
    it "accepts the beacon" do
      view

      expect(last_response.status).to eq(202)
    end

    it "accepts the beacon a browser sends, asking for anything" do
      view(headers: { "HTTP_ACCEPT" => "*/*" })

      expect(last_response.status).to eq(202)
    end

    it "answers with nothing to read" do
      view

      expect(last_response.body).to be_empty
    end

    it "sets no cookie" do
      view

      expect(last_response.headers.keys.map(&:downcase)).not_to include("set-cookie")
    end

    it "stores one event" do
      view

      expect(stored).to have(1).item
    end

    it "stores the page" do
      view

      expect(stored.first).to have_attributes(path: "/writing/hello", title: "Hello", read_seconds: 0)
    end

    it "stores no address" do
      view

      expect(stored.first.to_h.values.join(" ")).not_to include(address)
    end

    it "gives the same address and browser one visitor hash" do
      view
      view

      expect(stored.map(&:visitor_hash).uniq).to have(1).item
    end

    it "gives one visitor hash to a client forging its address behind the proxy" do
      forged("203.0.113.1")
      forged("203.0.113.2")

      expect(stored.map(&:visitor_hash).uniq).to have(1).item
    end

    it "looks the country up from the address the site trusts" do
      place = Analytics::Structs::Place.new(city: nil, country: "US", country_name: "United States")
      allow(Analytics::Slice["geo.countries"]).to receive(:place).with(loopback).and_return(place)
      forged("203.0.113.1")

      expect(stored.first.country_code).to eq("US")
    end

    it "stores a monthly visitor hash beside the daily one", :aggregate_failures do
      view

      expect(stored.first.month_visitor_hash).to match(/\A\h{64}\z/)
      expect(stored.first.month_visitor_hash).not_to eq(stored.first.visitor_hash)
    end

    it "gives a reader on two days in one month two daily hashes and one monthly hash", :aggregate_failures do
      [month - 3, month - 2].each { view_at(it) }

      expect(stored.map(&:visitor_hash).uniq).to have(2).items
      expect(stored.map(&:month_visitor_hash).uniq).to have(1).item
    end

    it "gives a reader a new monthly hash once the Chicago month turns" do
      [month - 1, month].each { view_at(it) }

      expect(stored.map(&:month_visitor_hash).uniq).to have(2).items
    end

    it "gives another browser another visitor hash" do
      view
      view(agent: "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/130.0")

      expect(stored.map(&:visitor_hash).uniq).to have(2).items
    end

    it "gives two addresses in one IPv6 /64 two visitor hashes, unlike the contact throttle" do
      %w[2001:db8:1:2::a 2001:db8:1:2::b].each { view(headers: { "REMOTE_ADDR" => it }) }

      expect(stored.map(&:visitor_hash).uniq).to have(2).items
    end

    describe "whose referrer runs past the cap" do
      before { view(referrer: "https://news.example/#{'a' * 2100}") }

      it "accepts the beacon" do
        expect(last_response.status).to eq(202)
      end

      it "stores the view" do
        expect(stored).to have(1).item
      end

      it "keeps no referrer" do
        expect(stored.first.referrer_host).to be_nil
      end
    end

    it "keeps only the host of the referrer" do
      view(referrer: "https://news.example/item?id=1")

      expect(stored.first.referrer_host).to eq("news.example")
    end

    it "counts a visit from the site itself as direct" do
      view(referrer: "http://example.org/writing")

      expect(stored.first.referrer_host).to be_nil
    end

    it "keeps the path of a page on the site that sent the reader" do
      view(referrer: "http://example.org/writing")

      expect(stored.first.referrer_path).to eq("/writing")
    end

    it "keeps no query with the path of a page on the site" do
      view(referrer: "http://example.org/writing/hello?ref=reddit")

      expect(stored.first.referrer_path).to eq("/writing/hello")
    end

    it "keeps no path for a referrer on another site" do
      view(referrer: "https://news.example/item")

      expect(stored.first.referrer_path).to be_nil
    end

    it "keeps no path when the site sent only its origin" do
      view(referrer: "http://example.org")

      expect(stored.first.referrer_path).to be_nil
    end

    it "counts the address's recent events once" do
      expect(counting { view }.grep(/\ASELECT count\(\*\).*address_hash/i)).to have(1).item
    end

    it "stores the ref the page was tagged with as its source" do
      view(ref: "reddit")

      expect(stored.first.source).to eq("reddit")
    end

    it "stores a ref of 32 characters" do
      view(ref: "a" * 32)

      expect(stored.first.source).to eq("a" * 32)
    end

    it "stores a hand-typed ref in lower case" do
      view(ref: " Mastodon ")

      expect(stored.first.source).to eq("mastodon")
    end

    it "stores no source for a view with no ref" do
      view

      expect(stored.first.source).to be_nil
    end

    [
      ["a ref with spaces in it", "news letter"],
      ["a ref with markup", "<b>x</b>"],
      ["a ref past 32 characters", "a" * 33],
      ["a blank ref", "  "],
      ["a null ref", nil],
    ].each do |named, ref|
      it "drops #{named} and still stores the view" do
        view(ref:)

        expect(stored.map(&:source)).to eq([nil])
      end
    end

    describe "the device class" do
      def view_from(user_agent)
        beacon({ kind: "view", path: "/writing/hello", view_token: token("first") }, agent: user_agent)
      end

      iphone = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)"
      ipad = "Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)"
      android = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0"
      webview = "Mozilla/5.0 (Linux; Android 14; Pixel 8; wv) AppleWebKit/537.36 Version/4.0 Chrome/129.0.0.0"

      [
        ["Chrome on a Mac", "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36", "desktop"],
        ["Firefox on Windows", "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) Firefox/131.0", "desktop"],
        ["Safari on an iPhone", "#{iphone} Version/18.0 Mobile/15E148 Safari/604.1", "mobile"],
        ["Chrome on an Android phone", "#{android} Mobile Safari/537.36", "mobile"],
        ["Safari on an iPad", "#{ipad} Version/18.0 Mobile/15E148 Safari/604.1", "tablet"],
        ["Chrome on an Android tablet", "#{android} Safari/537.36", "tablet"],
        ["the Mastodon app", "#{iphone} Mobile/15E148 Mastodon/2.6", "in-app"],
        ["the Bluesky app", "#{webview} Mobile Safari/537.36 Bluesky/1.92", "in-app"],
        ["the Reddit app", "#{iphone} Mobile/15E148 Reddit/Version_2024.40.0/Build_123", "in-app"],
        ["the Facebook app", "#{iphone} Mobile/15E148 [FBAN/FBIOS;FBAV/480.0.0.0]", "in-app"],
        ["the Instagram app", "#{webview} Mobile Safari/537.36 Instagram 350.0.0.0 Android", "in-app"],
        ["an Android web view", "#{webview} Mobile Safari/537.36", "in-app"],
        ["an iOS web view", "#{iphone} Mobile/15E148", "in-app"],
      ].each do |named, user_agent, device_class|
        it "stores #{named} as #{device_class}" do
          view_from(user_agent)

          expect(stored.map(&:device_class)).to eq([device_class])
        end
      end

      it "stores no part of the user agent" do
        view

        expect(stored.first.to_h.values.grep(String).grep(/Mozilla|Chrome/)).to be_empty
      end
    end

    it "keeps no title when the page sent a blank one" do
      view(title: "   ")

      expect(stored.first.title).to be_nil
    end

    it "counts two browsers on one address as two visitors in the rollup" do
      view
      view(agent: "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/130.0")
      roll_up_tomorrow

      expect(Analytics::Slice["repos.analytics_rollup_queries"].by_day(Blog::TimeZone.today - 1))
        .to have_attributes(visitors: 2)
    end
  end

  describe "a read" do
    before { view }

    it "stores the read time on the view" do
      read(42)

      expect(stored.first).to have_attributes(read_seconds: 42)
    end

    it "stores no second event" do
      read(42)

      expect(stored).to have(1).item
    end

    it "accepts the beacon" do
      read(42)

      expect(last_response.status).to eq(202)
    end

    it "accepts a second read from a page taken back from the cache" do
      read(42)
      read(600)

      expect(last_response.status).to eq(202)
    end

    it "raises the stored time on that second read" do
      read(42)
      read(600)

      expect(stored.first).to have_attributes(read_seconds: 600)
    end

    it "leaves the stored time alone when a later read is shorter" do
      read(600)
      read(42)

      expect(stored.first.read_seconds).to eq(600)
    end

    it "stores twenty minutes for a read that runs past it" do
      read(86_400)

      expect(stored.first.read_seconds).to eq(1_200)
    end

    describe "of one of two views of the page" do
      before { view(name: "second") }

      it "stores the read time on the view the beacon names, not the latest of the page" do
        read(42)

        expect(stored.map(&:read_seconds)).to eq([42, 0])
      end

      it "leaves another visitor's view alone" do
        read(42, agent: "Mozilla/5.0 Firefox/140.0")

        expect(stored.map(&:read_seconds)).to eq([0, 0])
      end
    end
  end

  describe "a read sent after midnight for a view from before it" do
    def across_midnight(day = Blog::TimeZone.today, after: 600)
      allow(Time).to receive(:now).and_return(Blog::TimeZone.day_start(day) - 600)
      view
      allow(Time).to receive(:now).and_return(Blog::TimeZone.day_start(day) + after)
      read(42)
    end

    it "accepts the beacon" do
      across_midnight

      expect(last_response.status).to eq(202)
    end

    it "stores the read time on the view" do
      across_midnight

      expect(stored.first).to have_attributes(read_seconds: 42)
    end

    it "stores the read time late into the next day" do
      across_midnight(after: 20 * 3_600)

      expect(stored.first).to have_attributes(read_seconds: 42)
    end

    it "stores the read time after a day the clocks went forward" do
      across_midnight(Date.new(2027, 3, 15))

      expect(stored.first).to have_attributes(read_seconds: 42)
    end

    it "stores the read time after a day the clocks went back" do
      across_midnight(Date.new(2027, 11, 8))

      expect(stored.first).to have_attributes(read_seconds: 42)
    end
  end

  describe "a read that matches no view" do
    before { view }

    it "turns the beacon away once two salt days have turned" do
      allow(Time).to receive(:now).and_return(Blog::TimeZone.day_start(Blog::TimeZone.today + 2))
      read(42)

      expect(last_response.status).to eq(400)
    end

    it "keeps the view with no read time once two salt days have turned" do
      allow(Time).to receive(:now).and_return(Blog::TimeZone.day_start(Blog::TimeZone.today + 2))
      read(42)

      expect(stored.first).to have_attributes(read_seconds: 0)
    end

    it "turns away a read under an unknown view token", :aggregate_failures do
      read(42, name: "second")

      expect(last_response.status).to eq(400)
      expect(stored.first).to have_attributes(read_seconds: 0)
    end

    it "turns away a read from another browser on the same address after midnight", :aggregate_failures do
      allow(Time).to receive(:now).and_return(Blog::TimeZone.day_start(Blog::TimeZone.today + 1))
      read(42, agent: "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/130.0")

      expect(last_response.status).to eq(400)
      expect(stored.first).to have_attributes(read_seconds: 0)
    end

    it "turns away a read of a page the visitor never opened" do
      read(42, path: "/about", name: "second")

      expect(last_response.status).to eq(400)
    end

    it "answers with nothing to read" do
      read(42, path: "/about", name: "second")

      expect(last_response.body).to be_empty
    end
  end

  describe "a click" do
    def click(name: "first", path: "/writing/hello", link_host: "docs.example", link_path: "/guide", **)
      beacon({ kind: "click", path:, view_token: token(name), link_host:, link_path: }.compact, **)
    end

    def clicks = event_repo.analytics_clicks.order(:id).to_a

    def view_of(path, name:) = beacon({ kind: "view", path:, title: "Page", view_token: token(name) })

    describe "on a post" do
      before { view }

      it "accepts the beacon" do
        click

        expect(last_response.status).to eq(202)
      end

      it "stores the link's host and path against the view" do
        click

        expect(clicks.map { it.to_h.values_at(:event_id, :link_host, :link_path) })
          .to eq([[stored.first.id, "docs.example", "/guide"]])
      end

      it "stores each click" do
        2.times { click }

        expect(clicks).to have(2).items
      end

      it "stores no second view" do
        click

        expect(stored).to have(1).item
      end

      it "turns away a click under an unknown view token", :aggregate_failures do
        click(name: "second")

        expect(last_response.status).to eq(400)
        expect(clicks).to be_empty
      end

      it "turns away a click past the cap on one view", :aggregate_failures do
        50.times { click }
        click

        expect(last_response.status).to eq(429)
        expect(clicks).to have(50).items
      end

      it "stores nothing while the operator is signed in" do
        sign_in_to_admin
        click

        expect(clicks).to be_empty
      end
    end

    describe "on one view that arrive together", :commits do
      let!(:statuses) { clicked_together }

      def cap = Analytics::Operations::RecordVisit::MAX_CLICKS

      def click_request
        link = { link_host: "docs.example", link_path: "/guide" }
        body = { kind: "click", path: "/writing/hello", view_token: token("first"), **link }.to_json
        headers = { "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => agent, "REMOTE_ADDR" => address }
        server = Rack::MockRequest.new(app)

        -> { server.post("/pulse", input: body, **headers).status }
      end

      def clicked_together
        view_one_click_short
        arrived, release = hold_each_click
        senders = Array.new(sent) { click_request }.map { |request| Thread.new { request.call } }
        sent.times { arrived.pop(timeout: 5) }
        sent.times { release << :go }
        senders.map(&:value)
      end

      def hold_each_click
        arrived = Thread::Queue.new
        release = Thread::Queue.new
        allow(event_repo).to receive(:record_click).and_wrap_original do |original, **attrs|
          arrived << true
          release.pop(timeout: 5)
          original.call(**attrs)
        end
        replace_component("repos.analytics_event_mutations", event_repo)

        [arrived, release]
      end

      def sent = 5

      def view_one_click_short
        view
        cap.pred.times { create(:analytics_click, event_id: stored.first.id) }
      end

      it "stores no more than the cap" do
        expect(clicks).to have(cap).items
      end

      it "tells every click past the cap it is throttled" do
        expect(statuses.tally).to eq(202 => 1, 429 => sent - 1)
      end
    end

    describe "under the token of a view of another page" do
      before do
        create(:post, :published, slug: "other")
        view_of("/writing/other", name: "other")
        click(name: "other")
      end

      it "turns the beacon away" do
        expect(last_response.status).to eq(400)
      end

      it "stores nothing" do
        expect(clicks).to be_empty
      end
    end

    {
      "the about page" => "/about",
      "the writing index" => "/writing",
      "a tag page" => "/writing/tags/ruby",
    }.each do |named, path|
      describe "on #{named}" do
        before do
          view_of(path, name: "page")
          click(path:, name: "page")
        end

        it "accepts the beacon" do
          expect(last_response.status).to eq(202)
        end

        it "stores nothing" do
          expect(clicks).to be_empty
        end
      end
    end

    {
      "with no host" => { link_host: nil },
      "with no path" => { link_path: nil },
      "to a host that is no host" => { link_host: "docs.example/guide" },
      "to a host in capitals" => { link_host: "Docs.Example" },
      "to a host past its cap" => { link_host: "#{'a' * 250}.example" },
      "carrying a query" => { link_path: "/guide?token=secret" },
      "carrying a fragment" => { link_path: "/guide#top" },
      "to a path that is no path" => { link_path: "guide" },
      "to a path past its cap" => { link_path: "/#{'a' * 2048}" },
      "carrying a control character" => { link_path: "/guide\u0001" },
    }.each do |named, link|
      describe named do
        before do
          view
          click(**link)
        end

        it "turns the beacon away" do
          expect(last_response.status).to eq(400)
        end

        it "stores nothing" do
          expect(clicks).to be_empty
        end
      end
    end
  end

  describe "a scroll" do
    it "starts a view at no depth when the page sent none" do
      view

      expect(stored.first.scroll_depth).to eq(0)
    end

    it "starts a view at the depth the page showed when it loaded" do
      view(scroll_depth: 100)

      expect(stored.first.scroll_depth).to eq(100)
    end

    describe "of a stored view" do
      before do
        view
        view(name: "second")
      end

      it "stores the depth on the view the beacon names, not the latest of the page" do
        scroll(50)

        expect(stored.map(&:scroll_depth)).to eq([50, 0])
      end

      it "keeps the deeper depth when a later one is shallower" do
        scroll(75)
        scroll(25)

        expect(stored.first.scroll_depth).to eq(75)
      end

      it "stores no second event" do
        scroll(25)

        expect(stored).to have(2).items
      end

      it "leaves another visitor's view alone" do
        scroll(50, agent: "Mozilla/5.0 Firefox/140.0")

        expect(stored.map(&:scroll_depth)).to eq([0, 0])
      end

      [30, 0, 125, nil].each do |depth|
        it "turns away a depth of #{depth.inspect}", :aggregate_failures do
          scroll(depth)

          expect(last_response.status).to eq(400)
          expect(stored.map(&:scroll_depth)).to eq([0, 0])
        end
      end

      it "turns away a scroll with no view token" do
        beacon({ kind: "scroll", path: "/writing/hello", scroll_depth: 50 })

        expect(last_response.status).to eq(400)
      end

      it "turns away a scroll of a view never stored" do
        scroll(50, name: "never")

        expect(last_response.status).to eq(400)
      end
    end
  end

  describe "a visit that is not counted" do
    it "stores nothing while the operator is signed in" do
      sign_in_to_admin
      view

      expect(stored).to be_empty
    end

    it "accepts the beacon while the operator is signed in" do
      sign_in_to_admin
      view

      expect(last_response.status).to eq(202)
    end

    it "stores nothing from a known bot" do
      view(agent: "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")

      expect(stored).to be_empty
    end

    it "stores nothing from a client with no user agent" do
      view(agent: nil)

      expect(stored).to be_empty
    end
  end

  describe "a path that names no page on the site" do
    def forgery = beacon({ kind: "view", path: "/wp-login.php", title: "Sign in" })

    it "turns the beacon away" do
      forgery

      expect(last_response.status).to eq(400)
    end

    it "stores nothing" do
      forgery

      expect(stored).to be_empty
    end

    {
      "a path under the admin" => "/admin/posts",
      "a path the beacon only posts to" => "/pulse",
      "a path that is not rooted" => "writing/hello",
      "a path pointing at another site" => "//evil.example",
      "a path carrying a query" => "/writing/hello?utm_source=spam",
      "a path carrying a fragment" => "/writing/hello#spam",
      "a path no URL can hold" => "/%",
      "a path that is not a string" => nil,
      "an empty path" => "",
    }.each do |named, path|
      it "turns away #{named}" do
        beacon({ kind: "view", path: })

        expect(last_response.status).to eq(400)
      end
    end
  end

  describe "a path that names a page on the site" do
    %w[/ /about /contact /projects /writing /writing/hello /writing/tags/ruby].each do |path|
      it "accepts #{path}" do
        beacon({ kind: "view", path: })

        expect(last_response.status).to eq(202)
      end

      it "stores #{path}" do
        beacon({ kind: "view", path: })

        expect(stored.map(&:path)).to eq([path])
      end
    end

    it "stores a tag only a project carries" do
      create(:project, name: "sai", tags: %w[go])
      beacon({ kind: "view", path: "/writing/tags/go" })

      expect(stored.map(&:path)).to eq(["/writing/tags/go"])
    end
  end

  describe "a path the router answers that names nothing on the site" do
    before { create(:post, :draft, slug: "unfinished", tags: %w[secret]) }

    {
      "a post that does not exist" => "/writing/nothing-here",
      "a draft" => "/writing/unfinished",
      "a slug no post can take" => "/writing/Not%20A%20Slug",
      "a slug that decodes to bad UTF-8" => "/writing/%FF",
      "a tag that does not exist" => "/writing/tags/nothing-here",
      "a tag only a draft carries" => "/writing/tags/secret",
      "a tag in another case than its own" => "/writing/tags/Ruby",
      "a tag that decodes to bad UTF-8" => "/writing/tags/%FF",
      "a media file" => "/media/made-up-key",
      "the manifest" => "/site.webmanifest",
      "the writing feed" => "/writing.atom",
      "a tag's feed" => "/writing/tags/ruby.atom",
    }.each do |named, path|
      it "accepts the beacon for #{named}" do
        beacon({ kind: "view", path: })

        expect(last_response.status).to eq(202)
      end

      it "stores nothing for #{named}" do
        beacon({ kind: "view", path: })

        expect(stored).to be_empty
      end
    end

    it "turns away a malformed beacon as it would for a real page" do
      beacon({ kind: "click", path: "/writing/nothing-here" })

      expect(last_response.status).to eq(400)
    end

    it "accepts the beacon past the limit and stores nothing", :aggregate_failures do
      lower_throttle_limit(:analytics, to: 1)
      2.times { view }
      beacon({ kind: "view", path: "/writing/nothing-here" })

      expect(last_response.status).to eq(202)
      expect(stored).to have(1).item
    end
  end

  describe "a beacon another site's page sent" do
    it "refuses one the browser marks cross-site", :aggregate_failures do
      view(headers: { "HTTP_SEC_FETCH_SITE" => "cross-site" })

      expect(last_response.status).to eq(403)
      expect(stored).to be_empty
    end

    it "refuses one the browser marks same-site, since a sibling host is not this one", :aggregate_failures do
      view(headers: { "HTTP_SEC_FETCH_SITE" => "same-site" })

      expect(last_response.status).to eq(403)
      expect(stored).to be_empty
    end

    it "refuses one from a browser that names only another origin", :aggregate_failures do
      view(headers: { "HTTP_ORIGIN" => "https://evil.example" })

      expect(last_response.status).to eq(403)
      expect(stored).to be_empty
    end

    it "refuses one from a browser that names a null origin", :aggregate_failures do
      view(headers: { "HTTP_ORIGIN" => "null" })

      expect(last_response.status).to eq(403)
      expect(stored).to be_empty
    end
  end

  describe "a beacon the site's own page sent" do
    it "stores one the browser marks same-origin", :aggregate_failures do
      view(headers: { "HTTP_SEC_FETCH_SITE" => "same-origin", "HTTP_ORIGIN" => "https://aaronmallen.me" })

      expect(last_response.status).to eq(202)
      expect(stored).to have(1).item
    end

    it "stores one the browser marks as asked for by nobody" do
      view(headers: { "HTTP_SEC_FETCH_SITE" => "none" })

      expect(stored).to have(1).item
    end

    it "stores one from a browser that names only the site's origin" do
      view(headers: { "HTTP_ORIGIN" => "https://aaronmallen.me" })

      expect(stored).to have(1).item
    end

    it "trusts the browser's mark over an origin it does not name" do
      view(headers: { "HTTP_SEC_FETCH_SITE" => "same-origin", "HTTP_ORIGIN" => "https://pi.local" })

      expect(stored).to have(1).item
    end

    it "stores one from a client that sends neither header", :aggregate_failures do
      view

      expect(last_response.status).to eq(202)
      expect(stored).to have(1).item
    end
  end

  describe "a run of beacons past the limit" do
    let(:limit) { Hanami.app["settings"].analytics[:throttle_limit] }

    before do
      lower_throttle_limit(:analytics, to: 5)
      (limit + 1).times { view }
    end

    it "comes back refused" do
      expect(last_response.status).to eq(429)
    end

    it "stores no more than the limit" do
      expect(stored).to have(limit).items
    end

    it "answers with nothing to read" do
      expect(last_response.body).to be_empty
    end
  end

  describe "a run of beacons past the limit from one address with a new browser on each" do
    let(:limit) { Hanami.app["settings"].analytics[:throttle_limit] }

    before do
      lower_throttle_limit(:analytics, to: 5)
      (limit + 1).times { |sent| view(agent: "Mozilla/5.0 x#{sent}") }
    end

    it "comes back refused" do
      expect(last_response.status).to eq(429)
    end

    it "stores no more than the limit" do
      expect(stored).to have(limit).items
    end
  end

  describe "a run of beacons past the limit from one IPv6 /64 with a new address on each" do
    let(:limit) { Hanami.app["settings"].analytics[:throttle_limit] }

    before do
      lower_throttle_limit(:analytics, to: 5)
      (limit + 1).times { |sent| view(headers: { "REMOTE_ADDR" => "2001:db8:1:2::#{sent + 1}" }) }
    end

    it "comes back refused" do
      expect(last_response.status).to eq(429)
    end

    it "stores no more than the limit" do
      expect(stored).to have(limit).items
    end

    it "keys the address hash on the network rather than the address" do
      network = Analytics::Slice["operations.hash_visitor"].call(address: "2001:db8:1:2::")

      expect(stored.map { it[:address_hash] }.uniq).to eq([network])
    end
  end

  describe "a beacon from a second IPv6 /64" do
    before do
      lower_throttle_limit(:analytics, to: 5)
      5.times { view(headers: { "REMOTE_ADDR" => "2001:db8:1:2::1" }) }
      view(headers: { "REMOTE_ADDR" => "2001:db8:1:3::1" })
    end

    it "goes through, since the first network spent only its own allowance" do
      expect(last_response.status).to eq(202)
    end
  end

  describe "a read from an address that has reached the limit" do
    before do
      view
      view(name: "second")
      lower_throttle_limit(:analytics, to: 2)
      read(42)
    end

    it "comes back refused" do
      expect(last_response.status).to eq(429)
    end

    it "stores no read time" do
      expect(stored.map(&:read_seconds)).to eq([0, 0])
    end
  end

  describe "a scroll from an address that has reached the limit" do
    before do
      view
      view(name: "second")
      lower_throttle_limit(:analytics, to: 2)
      scroll(50)
    end

    it "comes back refused" do
      expect(last_response.status).to eq(429)
    end

    it "stores no depth" do
      expect(stored.map(&:scroll_depth)).to eq([0, 0])
    end
  end

  describe "views from one address that arrive together", :commits do
    before { Analytics::Slice.start(:geo) }

    let!(:statuses) { checked_together }

    def checked_together
      lower_throttle_limit(:analytics, to: limit)
      arrived, release = hold_each_claim
      senders = Array.new(sent) { view_request(it) }.map { |request| Thread.new { request.call } }
      sent.times { arrived.pop(timeout: 5) }
      sent.times { release << :go }
      senders.map(&:value)
    end

    def hold_each_claim
      arrived = Thread::Queue.new
      release = Thread::Queue.new
      allow(event_repo).to receive(:claim).and_wrap_original do |original, **attrs|
        arrived << true
        release.pop(timeout: 5)
        original.call(**attrs)
      end
      replace_component("repos.analytics_event_mutations", event_repo)

      [arrived, release]
    end

    def limit = 5

    def sent = limit + 3

    def view_request(index)
      body = { kind: "view", path: "/writing/hello", view_token: token("view-#{index}") }.to_json
      headers = { "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => agent, "REMOTE_ADDR" => address }
      server = Rack::MockRequest.new(app)

      -> { server.post("/pulse", input: body, **headers).status }
    end

    it "stores no more than the limit" do
      expect(stored).to have(limit).items
    end

    it "tells every view past the limit it is throttled" do
      expect(statuses.tally).to eq(202 => limit, 429 => sent - limit)
    end
  end

  describe "a malformed payload" do
    it "rejects a body that is not JSON" do
      post "/pulse", "kind=view", "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => agent

      expect(last_response.status).to eq(400)
    end

    it "rejects a body too big to be a visit" do
      beacon({ kind: "view", path: "/#{'a' * 9000}" })

      expect(last_response.status).to eq(400)
    end

    it "rejects an empty body" do
      post "/pulse", "", "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => agent

      expect(last_response.status).to eq(400)
    end

    it "answers nothing to read for a body that is not JSON" do
      post "/pulse", "kind=view", "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => agent

      expect(last_response.body).to be_empty
    end

    it "rejects an unknown kind" do
      beacon({ kind: "share", path: "/writing/hello" })

      expect(last_response.status).to eq(400)
    end

    it "rejects a path past its cap" do
      beacon({ kind: "view", path: "/writing/#{'a' * 2048}" })

      expect(last_response.status).to eq(400)
    end

    it "rejects a title past its cap" do
      beacon({ kind: "view", path: "/writing/hello", title: "a" * 513 })

      expect(last_response.status).to eq(400)
    end

    it "rejects a read with no time" do
      beacon({ kind: "read", path: "/writing/hello", view_token: token("first") })

      expect(last_response.status).to eq(400)
    end

    it "rejects a read naming no view" do
      beacon({ kind: "read", path: "/writing/hello", read_seconds: 42 })

      expect(last_response.status).to eq(400)
    end

    it "rejects a view token that is not a token" do
      beacon({ kind: "view", path: "/writing/hello", view_token: "not-a-token" })

      expect(last_response.status).to eq(400)
    end

    it "stores nothing" do
      beacon({ kind: "share", path: "/writing/hello" })

      expect(stored).to be_empty
    end
  end

  describe "a payload carrying a control character" do
    it "turns away a NUL byte in the path" do
      beacon({ kind: "view", path: "/writing/hello\u0000" })

      expect(last_response.status).to eq(400)
    end

    it "turns away a NUL byte in the title" do
      beacon({ kind: "view", path: "/writing/hello", title: "Hello\u0000" })

      expect(last_response.status).to eq(400)
    end

    it "turns away a control character that is not a NUL byte in the title" do
      beacon({ kind: "view", path: "/writing/hello", title: "Hello\u0001" })

      expect(last_response.status).to eq(400)
    end

    it "stores nothing" do
      beacon({ kind: "view", path: "/writing/hello", title: "Hello\u0000" })

      expect(stored).to be_empty
    end
  end

  it "answers only to POST" do
    get "/pulse"

    expect(last_response.status).to eq(405)
  end

  describe "the beacon on the page" do
    %w[/ /about /contact /projects /writing].each do |path|
      it "loads on #{path}" do
        get path

        expect(Capybara.string(last_response.body)).to have_css("body[data-beacon='/pulse']", visible: :all)
      end
    end

    it "stays off the admin" do
      sign_in_to_admin
      get "/admin"

      expect(Capybara.string(last_response.body)).to have_no_css("body[data-beacon]", visible: :all)
    end

    it "counts clicks on a post" do
      get "/writing/hello"

      expect(Capybara.string(last_response.body)).to have_css("body[data-beacon-clicks]", visible: :all)
    end

    %w[/ /about /contact /projects /writing /writing/tags/ruby].each do |path|
      it "counts no clicks on #{path}" do
        get path

        expect(Capybara.string(last_response.body)).to have_no_css("body[data-beacon-clicks]", visible: :all)
      end
    end

    %w[/ /writing].each do |path|
      it "loads no script from another site on #{path}" do
        get path

        expect(assets).to all(start_with("/"))
      end
    end

    it "loads no script from another site on the admin" do
      sign_in_to_admin
      get "/admin"

      expect(assets).to all(start_with("/"))
    end
  end

  def token(name) = Digest::SHA256.hexdigest("view-#{name}")[0, 32]

  def view(name: "first", agent: self.agent, headers: {}, **visit)
    beacon({ kind: "view", path: "/writing/hello", title: "Hello", view_token: token(name), **visit }, agent:, headers:)
  end

  def view_at(day)
    allow(Time).to receive(:now).and_return(Blog::TimeZone.day_start(day) + (12 * 3_600))
    view
  end
end

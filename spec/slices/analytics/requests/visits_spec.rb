# frozen_string_literal: true

require "digest"

RSpec.describe "Visit counting", type: :request do
  let(:agent) { "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36" }
  let(:event_repo) { Analytics::Slice["repos.analytics_event_repo"] }

  before { create(:post, :published, slug: "hello") }

  def beacon(visit, agent: self.agent)
    post "/pulse", visit.to_json, "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => agent,
                                  "REMOTE_ADDR" => "203.0.113.7"
  end

  def read(seconds, name: "first", **)
    beacon({ kind: "read", path: "/writing/hello", read_seconds: seconds, view_token: token(name) }, **)
  end

  def stored = event_repo.analytics_events.order(:occurred_at, :id).to_a

  def token(name) = Digest::SHA256.hexdigest("view-#{name}")[0, 32]

  def view(name: "first", **) = beacon({ kind: "view", path: "/writing/hello", view_token: token(name), ** })

  describe "a view" do
    it "keeps only the host of the referrer" do
      view(referrer: "https://news.example/item?id=1")

      expect(stored.first.referrer_host).to eq("news.example")
    end

    it "keeps no referrer that runs past the cap" do
      view(referrer: "https://news.example/#{'a' * 2048}")

      expect(stored.first.referrer_host).to be_nil
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
      ["a ref past #{Analytics::Ref::MAX_SOURCE} characters", "a" * (Analytics::Ref::MAX_SOURCE + 1)],
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
  end

  describe "a read" do
    before do
      view
      view(name: "second")
    end

    it "stores the read time on the view the beacon names, not the latest of the page" do
      read(42)

      expect(stored.map(&:read_seconds)).to eq([42, 0])
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

    it "leaves another visitor's view alone" do
      read(42, agent: "Mozilla/5.0 Firefox/140.0")

      expect(stored.map(&:read_seconds)).to eq([0, 0])
    end

    it "is throttled once the address has reached the limit", :aggregate_failures do
      lower_throttle_limit(:analytics, to: 2)
      read(42)

      expect(last_response.status).to eq(429)
      expect(stored.map(&:read_seconds)).to eq([0, 0])
    end
  end

  describe "a scroll" do
    def scroll(depth, name: "first", **)
      beacon({ kind: "scroll", path: "/writing/hello", scroll_depth: depth, view_token: token(name) }, **)
    end

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

      it "is throttled once the address has reached the limit", :aggregate_failures do
        lower_throttle_limit(:analytics, to: 2)
        scroll(50)

        expect(last_response.status).to eq(429)
        expect(stored.map(&:scroll_depth)).to eq([0, 0])
      end
    end
  end

  describe "views from one address that arrive together", :commits do
    let(:limit) { 5 }
    let(:sent) { limit + 3 }
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
      replace_component("repos.analytics_event_repo", event_repo)

      [arrived, release]
    end

    def view_request(index)
      body = { kind: "view", path: "/writing/hello", view_token: token("view-#{index}") }.to_json
      headers = { "CONTENT_TYPE" => "application/json", "HTTP_USER_AGENT" => agent, "REMOTE_ADDR" => "203.0.113.7" }
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
end

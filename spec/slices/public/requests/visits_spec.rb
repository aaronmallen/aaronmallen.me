# frozen_string_literal: true

require "digest"

RSpec.describe "Visits", type: :request do
  let(:address) { "203.0.113.7" }
  let(:agent) { "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36" }
  let(:event_repo) { Analytics::Slice["repos.analytics_event_repo"] }
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

  def read(seconds, name: "first", path: "/writing/hello")
    beacon({ kind: "read", path:, read_seconds: seconds, view_token: token(name) })
  end

  def roll_up_tomorrow
    allow(Time).to receive(:now).and_return(Time.now + 86_400)
    Analytics::Jobs::RollUpAnalytics.new.perform
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
      allow(Analytics::Slice["geo.countries"]).to receive(:code).with(loopback).and_return("US")
      forged("203.0.113.1")

      expect(stored.first.country_code).to eq("US")
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

    it "accepts a view whose referrer runs past the cap" do
      beacon({ kind: "view", path: "/writing/hello", referrer: "https://news.example/#{'a' * 2100}" })

      expect(last_response.status).to eq(202)
    end

    it "stores a view whose referrer runs past the cap" do
      beacon({ kind: "view", path: "/writing/hello", referrer: "https://news.example/#{'a' * 2100}" })

      expect(stored).to have(1).item
    end

    it "counts two browsers on one address as two visitors in the rollup" do
      view
      view(agent: "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/130.0")
      roll_up_tomorrow

      expect(Analytics::Slice["repos.analytics_rollup_repo"].by_day(Blog::TimeZone.today - 1))
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
  end

  describe "a read that matches no view" do
    before { view }

    it "turns the beacon away once the salt day has turned" do
      allow(Time).to receive(:now).and_return(Time.now + 86_400)
      read(42)

      expect(last_response.status).to eq(400)
    end

    it "keeps the view with no read time once the salt day has turned" do
      allow(Time).to receive(:now).and_return(Time.now + 86_400)
      read(42)

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
      "a tag that does not exist" => "/writing/tags/nothing-here",
      "a tag only a draft carries" => "/writing/tags/secret",
      "a tag in another case than its own" => "/writing/tags/Ruby",
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
      beacon({ kind: "click", path: "/writing/hello" })

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
      beacon({ kind: "click", path: "/writing/hello" })

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

  def view(**) = beacon({ kind: "view", path: "/writing/hello", title: "Hello", view_token: token("first") }, **)
end

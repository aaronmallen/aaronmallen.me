# frozen_string_literal: true

RSpec.describe "MCP analytics tools", type: :request do
  def roll_up(day, views:, visitors:)
    create(:analytics_rollup, day:, views:, visitors:, read_seconds: views * 10)
  end

  def today = Blog::TimeZone.today

  describe "read_analytics" do
    def read(from: today - 6, to: today) = mcp_answer("read_analytics", from: from.iso8601, to: to.iso8601)

    it "adds up the days inside the range" do
      roll_up(today - 1, views: 10, visitors: 4)
      roll_up(today - 2, views: 5, visitors: 2)

      expect(read.fetch("totals")).to eq("views" => 15, "visitors" => 6, "read_seconds" => 150, "reach" => 0)
    end

    it "leaves out the days outside the range" do
      roll_up(today - 1, views: 10, visitors: 4)
      roll_up(today - 9, views: 99, visitors: 9)

      expect(read.fetch("totals").fetch("views")).to eq(10)
    end

    it "gives views and visitors for every day, oldest first, with zero on a quiet day" do
      roll_up(today - 1, views: 10, visitors: 4)
      quiet = { "day" => (today - 2).iso8601, "views" => 0, "visitors" => 0 }
      busy = { "day" => (today - 1).iso8601, "views" => 10, "visitors" => 4 }

      expect(read(from: today - 2, to: today - 1).fetch("days")).to eq([quiet, busy])
    end

    it "ranks the paths by views over the range" do
      day = roll_up(today - 1, views: 50, visitors: 30).day
      create(:analytics_rollup_path, day:, path: "/writing/quiet", views: 5, visitors: 5, bounces: 0)
      create(:analytics_rollup_path, day:, path: "/writing/loud", views: 40, visitors: 20, bounces: 0)

      expect(read.fetch("paths").map { it.fetch("path") }).to eq(%w[/writing/loud /writing/quiet])
    end

    it "sums a path across the days of the range" do
      first = roll_up(today - 2, views: 10, visitors: 5).day
      second = roll_up(today - 1, views: 10, visitors: 5).day
      create(:analytics_rollup_path, day: first, path: "/writing/hello", views: 3, visitors: 2, bounces: 0)
      create(:analytics_rollup_path, day: second, path: "/writing/hello", views: 4, visitors: 3, bounces: 0)

      expect(read.fetch("paths").first).to include("path" => "/writing/hello", "views" => 7, "visitors" => 5)
    end

    it "gives the referrers, a direct visit as null" do
      day = roll_up(today - 1, views: 10, visitors: 5).day
      create(:analytics_rollup_referrer, day:, host: "news.example", views: 6)
      create(:analytics_rollup_referrer, :direct, day:, views: 4)

      expect(read.fetch("referrers").map { it.values_at("host", "views") }).to eq([["news.example", 6], [nil, 4]])
    end

    it "gives the countries" do
      day = roll_up(today - 1, views: 10, visitors: 5).day
      create(:analytics_rollup_country, day:, country_code: "DE", views: 3)
      create(:analytics_rollup_country, day:, country_code: "US", views: 7)

      expect(read.fetch("countries").map { it.values_at("country_code", "views") }).to eq([["US", 7], ["DE", 3]])
    end

    it "ranks the referrers by visitors over the range" do
      day = roll_up(today - 1, views: 20, visitors: 10).day
      create(:analytics_rollup_referrer, day:, host: "busy.example", views: 9, visitors: 2)
      create(:analytics_rollup_referrer, day:, host: "wide.example", views: 5, visitors: 4)

      expect(read.fetch("referrers").map { it.values_at("host", "views", "visitors") })
        .to eq([["wide.example", 5, 4], ["busy.example", 9, 2]])
    end

    it "ranks the countries by visitors over the range" do
      day = roll_up(today - 1, views: 20, visitors: 10).day
      create(:analytics_rollup_country, day:, country_code: "DE", views: 9, visitors: 2)
      create(:analytics_rollup_country, day:, country_code: "US", views: 5, visitors: 4)

      expect(read.fetch("countries").map { it.values_at("country_code", "views", "visitors") })
        .to eq([["US", 5, 4], ["DE", 9, 2]])
    end

    describe "a range that reaches past the event window" do
      before do
        older = roll_up(today - 5, views: 20, visitors: 10).day
        newer = roll_up(today - 1, views: 20, visitors: 10).day
        create(:analytics_rollup_referrer, day: older, host: "news.example", views: 6)
        create(:analytics_rollup_referrer, day: newer, host: "news.example", views: 2, visitors: 1)
        create(:analytics_rollup_referrer, day: older, host: "old.example", views: 9)
        create(:analytics_rollup_country, day: older, country_code: "US", views: 6)
        create(:analytics_event, referrer_host: "news.example", country_code: "US")
      end

      it "sums the visitors of the days that counted them" do
        expect(read.fetch("referrers").first).to include("host" => "news.example", "views" => 9, "visitors" => 2)
      end

      it "gives no visitors for a referrer with no counted day, after the ones with a count" do
        expect(read.fetch("referrers").last).to include("host" => "old.example", "views" => 9, "visitors" => nil)
      end

      it "adds today's visitors to a country with no counted day" do
        expect(read.fetch("countries")).to eq([{ "country_code" => "US", "views" => 7, "visitors" => 1 }])
      end
    end

    it "counts today from the visits before they roll up" do
      create(:analytics_event, path: "/writing/today", referrer_host: "news.example", country_code: "US")

      expect(read.fetch("paths").map { it.fetch("path") }).to eq(%w[/writing/today])
    end

    describe "today's visitors" do
      before do
        visitor_hash = "a" * 64
        2.times { create(:analytics_event, referrer_host: "news.example", country_code: "US", visitor_hash:) }
        create(:analytics_event, referrer_host: "blog.example", country_code: "US", visitor_hash:)
      end

      it "counts a visitor once under each referrer they came from" do
        expect(read.fetch("referrers").map { it.values_at("host", "views", "visitors") })
          .to eq([["news.example", 2, 1], ["blog.example", 1, 1]])
      end

      it "counts a visitor once under their country" do
        expect(read.fetch("countries").map { it.values_at("country_code", "views", "visitors") }).to eq([["US", 3, 1]])
      end
    end

    it "puts today's visits on today" do
      create(:analytics_event)

      expect(read.fetch("days").last).to eq("day" => today.iso8601, "views" => 1, "visitors" => 1)
    end

    describe "earlier days not rolled up yet" do
      def noon(day) = Blog::TimeZone.day_start(day) + (12 * 3_600)

      before do
        roll_up(today - 3, views: 4, visitors: 2)
        create(:analytics_event, path: "/writing/rolled", occurred_at: noon(today - 3))
        create(:analytics_event, path: "/writing/early", referrer_host: "old.example", occurred_at: noon(today - 2))
        2.times { create(:analytics_event, path: "/writing/late", country_code: "DE", occurred_at: noon(today - 1)) }
      end

      it "counts every unrolled day in the totals" do
        expect(read.fetch("totals")).to eq("views" => 7, "visitors" => 5, "read_seconds" => 166, "reach" => 0)
      end

      it "puts each unrolled day's visits on that day" do
        expect(read.fetch("days").last(3).map { it.values_at("views", "visitors") }).to eq([[1, 1], [2, 2], [0, 0]])
      end

      it "reads a rolled up day from its rollup" do
        expect(read.fetch("days")[-4]).to eq("day" => (today - 3).iso8601, "views" => 4, "visitors" => 2)
      end

      it "ranks the paths of every unrolled day and none of a rolled up day's events" do
        expect(read.fetch("paths").map { it.fetch("path") }).to eq(%w[/writing/late /writing/early])
      end

      it "gives the referrers and countries of every unrolled day", :aggregate_failures do
        expect(read.fetch("referrers").map { it.values_at("host", "views") })
          .to eq([["news.example", 2], ["old.example", 1]])
        expect(read.fetch("countries").map { it.values_at("country_code", "views") }).to eq([["DE", 2], ["US", 1]])
      end
    end

    it "sends no more than the top #{MCP::Tools::ReadAnalytics::TOP} paths" do
      day = roll_up(today - 1, views: 100, visitors: 50).day
      (MCP::Tools::ReadAnalytics::TOP + 1).times do
        create(:analytics_rollup_path, day:, views: 2, visitors: 1, bounces: 0)
      end

      expect(read.fetch("paths").length).to eq(MCP::Tools::ReadAnalytics::TOP)
    end

    it "names the time zone its days run on" do
      expect(read.fetch("time_zone")).to eq("America/Chicago")
    end

    it "refuses a day it cannot read" do
      expect(mcp_text("read_analytics", from: "last week", to: today.iso8601))
        .to eq("give from and to as days, such as 2026-01-01")
    end

    it "refuses a range that runs backwards" do
      expect(mcp_text("read_analytics", from: today.iso8601, to: (today - 1).iso8601)).to eq("from comes after to")
    end
  end

  describe "read_analytics reach" do
    let(:address) { "203.0.113.7" }
    let(:agent) { "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0.0.0 Safari/537.36" }
    let(:month) { Date.new(today.year, today.month, 1) }
    let(:old_month) { Date.new((today - 150).year, (today - 150).month, 1) }

    def hashed(at, period = Analytics::Operations::HashVisitor::DAY)
      Analytics::Slice["operations.hash_visitor"].call(address:, user_agent: agent, at:, period:)
    end

    def noon(day) = Blog::TimeZone.day_start(day) + (12 * 3_600)

    def read_reach(from, to, **) = mcp_answer("read_analytics", from: from.iso8601, to: to.iso8601, **).fetch("totals")

    def view(day, path: "/writing/hello")
      at = noon(day)
      month_visitor_hash = hashed(at, Analytics::Operations::HashVisitor::MONTH)

      create(:analytics_event, path:, visitor_hash: hashed(at), month_visitor_hash:, occurred_at: at)
    end

    it "counts a reader on two days in one month as two visitors and one reach" do
      [month - 3, month - 2].each { view(it) }

      expect(read_reach(month - 3, month - 2)).to include("visitors" => 2, "reach" => 1)
    end

    it "counts a reader on the last day of one month and the first of the next as two reach" do
      [month - 1, month].each { view(it) }

      expect(read_reach(month - 1, month)).to include("visitors" => 2, "reach" => 2)
    end

    it "counts a reader of two pages once for the site" do
      view(month, path: "/writing/hello")
      view(month, path: "/writing/other")

      expect(read_reach(month, today)).to include("views" => 2, "reach" => 1)
    end

    it "counts the reach of one page alone" do
      view(month, path: "/writing/hello")
      create(:analytics_event, path: "/writing/other", occurred_at: noon(month))

      expect(read_reach(month, today, path: "/writing/hello")).to include("reach" => 1)
    end

    it "reads a whole month past the raw visits from its rollup" do
      create(:analytics_rollup_reach, month: old_month, reach: 7)
      create(:analytics_rollup_reach, month: old_month, path: "/writing/hello", reach: 3)

      expect(read_reach(old_month, old_month.next_month - 1)).to include("reach" => 7)
    end

    it "reads one page's reach for a whole month past the raw visits" do
      create(:analytics_rollup_reach, month: old_month, reach: 7)
      create(:analytics_rollup_reach, month: old_month, path: "/writing/hello", reach: 3)

      expect(read_reach(old_month, old_month.next_month - 1, path: "/writing/hello")).to include("reach" => 3)
    end

    it "counts no reach for a page nobody read in a rolled up month" do
      create(:analytics_rollup_reach, month: old_month, reach: 7)

      expect(read_reach(old_month, old_month.next_month - 1, path: "/nowhere")).to include("reach" => 0)
    end

    it "adds the rolled up months to the months the raw visits still hold" do
      rolled = (old_month..(today - 89)).map { Date.new(it.year, it.month, 1) }.uniq
      rolled.each { create(:analytics_rollup_reach, month: it, reach: 7) }
      view(month)

      expect(read_reach(old_month, today)).to include("reach" => (7 * rolled.size) + 1)
    end

    it "gives no reach for part of a month past the raw visits" do
      create(:analytics_rollup_reach, month: old_month, reach: 7)

      expect(read_reach(old_month + 1, old_month.next_month - 1)).to include("reach" => nil)
    end
  end

  describe "read_analytics sources" do
    def figures(rows) = rows.map { it.values_at("source", "views", "visitors") }

    def read_sources(from: today - 6, to: today, **)
      mcp_answer("read_analytics", from: from.iso8601, to: to.iso8601, **).fetch("sources")
    end

    def roll_up_source(day, source, path: nil, views: 5, visitors: 3)
      create(:analytics_rollup, day:) unless Analytics::Slice["repos.analytics_rollup_repo"].by_day(day)
      create(:analytics_rollup_source, day:, path:, source:, views:, visitors:)
    end

    it "ranks the site's sources by visitors over the range" do
      roll_up_source(today - 2, "feed", views: 9, visitors: 2)
      roll_up_source(today - 1, "reddit", views: 4, visitors: 3)
      roll_up_source(today - 1, "feed", views: 1, visitors: 1)

      expect(figures(read_sources)).to eq([["feed", 10, 3], ["reddit", 4, 3]])
    end

    it "reads the site's sources apart from each page's" do
      roll_up_source(today - 1, "reddit", visitors: 2)
      roll_up_source(today - 1, "reddit", path: "/writing/hello", views: 40, visitors: 30)

      expect(figures(read_sources)).to eq([["reddit", 5, 2]])
    end

    it "gives one page's sources with a path" do
      roll_up_source(today - 1, "reddit", path: "/writing/hello", views: 4, visitors: 2)
      roll_up_source(today - 1, "feed", path: "/writing/other")
      roll_up_source(today - 1, "feed")

      expect(figures(read_sources(path: "/writing/hello"))).to eq([["reddit", 4, 2]])
    end

    describe "today, before it rolls up" do
      before do
        reader = Digest::SHA256.hexdigest("reader")
        2.times { create(:analytics_event, path: "/writing/hello", source: "mastodon", visitor_hash: reader) }
        create(:analytics_event, path: "/writing/other", source: "mastodon")
        create(:analytics_event, path: "/writing/other")
      end

      it "counts the site's sources from the visits" do
        expect(figures(read_sources)).to eq([["mastodon", 3, 2]])
      end

      it "counts one page's sources from the visits" do
        expect(figures(read_sources(path: "/writing/hello"))).to eq([["mastodon", 2, 1]])
      end
    end

    it "keeps a page's sources past the 90 days of raw visits" do
      old = today - 200
      roll_up_source(old, "bluesky", path: "/writing/hello")

      expect(figures(read_sources(from: old, to: old, path: "/writing/hello"))).to eq([["bluesky", 5, 3]])
    end

    it "gives no sources when no visit carried a ref" do
      create(:analytics_event)

      expect(read_sources).to eq([])
    end
  end

  describe "read_analytics devices" do
    def figures(rows) = rows.map { it.values_at("device_class", "views", "visitors") }

    def read_devices(from: today - 6, to: today, **)
      mcp_answer("read_analytics", from: from.iso8601, to: to.iso8601, **).fetch("devices")
    end

    def roll_up_device(day, device_class, path: nil, views: 5, visitors: 3)
      create(:analytics_rollup, day:) unless Analytics::Slice["repos.analytics_rollup_repo"].by_day(day)
      create(:analytics_rollup_device, day:, path:, device_class:, views:, visitors:)
    end

    it "ranks the site's device classes by visitors over the range" do
      roll_up_device(today - 2, "mobile", views: 9, visitors: 2)
      roll_up_device(today - 1, "in-app", views: 4, visitors: 3)
      roll_up_device(today - 1, "mobile", views: 1, visitors: 1)

      expect(figures(read_devices)).to eq([["mobile", 10, 3], ["in-app", 4, 3]])
    end

    it "reads the site's device classes apart from each page's" do
      roll_up_device(today - 1, "desktop", visitors: 2)
      roll_up_device(today - 1, "desktop", path: "/writing/hello", views: 40, visitors: 30)

      expect(figures(read_devices)).to eq([["desktop", 5, 2]])
    end

    it "gives one page's device classes with a path" do
      roll_up_device(today - 1, "tablet", path: "/writing/hello", views: 4, visitors: 2)
      roll_up_device(today - 1, "desktop", path: "/writing/other")
      roll_up_device(today - 1, "desktop")

      expect(figures(read_devices(path: "/writing/hello"))).to eq([["tablet", 4, 2]])
    end

    describe "today, before it rolls up" do
      before do
        reader = Digest::SHA256.hexdigest("reader")
        2.times { create(:analytics_event, path: "/writing/hello", device_class: "in-app", visitor_hash: reader) }
        create(:analytics_event, path: "/writing/other", device_class: "in-app")
        create(:analytics_event, path: "/writing/other")
      end

      it "counts the site's device classes from the visits" do
        expect(figures(read_devices)).to eq([["in-app", 3, 2]])
      end

      it "counts one page's device classes from the visits" do
        expect(figures(read_devices(path: "/writing/hello"))).to eq([["in-app", 2, 1]])
      end
    end

    it "keeps a page's device classes past the 90 days of raw visits" do
      old = today - 200
      roll_up_device(old, "mobile", path: "/writing/hello")

      expect(figures(read_devices(from: old, to: old, path: "/writing/hello"))).to eq([["mobile", 5, 3]])
    end
  end

  describe "read_analytics with a path" do
    def late_evening(day) = Blog::TimeZone.day_start(day) + (23 * 3_600) + 1_800

    def page_day(views) = { "views" => views, "visitors" => [views - 1, 0].max, "read_seconds" => views * 10 }

    def read_page(path, from: today - 6, to: today)
      mcp_answer("read_analytics", from: from.iso8601, to: to.iso8601, path:)
    end

    def roll_up_page(day, path, views:)
      roll_up(day, views: 50, visitors: 20)
      create(:analytics_rollup_path, day:, path:, views:, visitors: views - 1, read_seconds: views * 10, bounces: 0)
    end

    it "gives the totals of that page only" do
      roll_up_page(today - 2, "/writing/hello", views: 4)
      create(:analytics_rollup_path, day: today - 2, path: "/writing/other", views: 9, visitors: 9, bounces: 0)
      roll_up_page(today - 1, "/writing/hello", views: 6)

      expect(read_page("/writing/hello").fetch("totals"))
        .to eq("views" => 10, "visitors" => 8, "read_seconds" => 100, "reach" => 0)
    end

    it "gives the page's days, oldest first, with zero on a quiet day" do
      roll_up_page(today - 1, "/writing/hello", views: 4)
      days = { 2 => 0, 1 => 4 }.map { |ago, views| { "day" => (today - ago).iso8601, **page_day(views) } }

      expect(read_page("/writing/hello", from: today - 2, to: today - 1).fetch("days")).to eq(days)
    end

    it "counts the page's visits before they roll up" do
      2.times { create(:analytics_event, path: "/writing/hello", read_seconds: 30) }
      create(:analytics_event, path: "/writing/other")

      expect(read_page("/writing/hello").fetch("days").last)
        .to eq("day" => today.iso8601, "views" => 2, "visitors" => 2, "read_seconds" => 60)
    end

    it "leaves out the site's top lists" do
      expect(read_page("/writing/hello").keys)
        .to eq(%w[from to time_zone path totals days referrers countries sources devices hours read_spread])
    end

    describe "the page's referrers and countries" do
      def counted(answer, list, key) = answer.fetch(list).map { it.values_at(key, "views", "visitors") }

      def origins(path = "/writing/hello", **)
        answer = read_page(path, **)
        { referrers: counted(answer, "referrers", "host"), countries: counted(answer, "countries", "country_code") }
      end

      def roll_up_origin(factory, day, *, path: "/writing/hello", **)
        roll_up(day, views: 50, visitors: 20) unless Analytics::Slice["repos.analytics_rollup_repo"].by_day(day)
        create(factory, *, day:, path:, **)
      end

      it "ranks the page's referrers by visitors over the range, with a direct visit under no host" do
        roll_up_origin(:analytics_rollup_page_referrer, today - 2, host: "news.example", views: 3, visitors: 2)
        roll_up_origin(:analytics_rollup_page_referrer, today - 1, host: "news.example", views: 2, visitors: 2)
        roll_up_origin(:analytics_rollup_page_referrer, today - 1, :direct, views: 9, visitors: 3)

        expect(origins.fetch(:referrers)).to eq([["news.example", 5, 4], [nil, 9, 3]])
      end

      it "ranks the page's countries by visitors over the range" do
        roll_up_origin(:analytics_rollup_page_country, today - 1, country_code: "JP", views: 2, visitors: 1)
        roll_up_origin(:analytics_rollup_page_country, today - 1, country_code: "US", views: 6, visitors: 4)

        expect(origins.fetch(:countries)).to eq([["US", 6, 4], ["JP", 2, 1]])
      end

      it "leaves out other pages and the whole site's" do
        roll_up_origin(:analytics_rollup_page_referrer, today - 1, path: "/writing/other")
        roll_up_origin(:analytics_rollup_page_country, today - 1, path: "/writing/other")
        create(:analytics_rollup_referrer, day: today - 1, visitors: 5)
        create(:analytics_rollup_country, day: today - 1, visitors: 5)

        expect(origins).to eq(referrers: [], countries: [])
      end

      it "counts the page's visits before they roll up" do
        reader = Digest::SHA256.hexdigest("reader")
        2.times { create(:analytics_event, path: "/writing/hello", country_code: "JP", visitor_hash: reader) }
        create(:analytics_event, path: "/writing/other")

        expect(origins).to eq(referrers: [["news.example", 2, 1]], countries: [["JP", 2, 1]])
      end

      it "keeps the page's referrers and countries past the 90 days of raw visits" do
        old = today - 200
        roll_up_origin(:analytics_rollup_page_referrer, old, host: "news.example", views: 5, visitors: 3)
        roll_up_origin(:analytics_rollup_page_country, old, country_code: "JP", views: 5, visitors: 3)

        expect(origins(from: old, to: old)).to eq(referrers: [["news.example", 5, 3]], countries: [["JP", 5, 3]])
      end
    end

    it "answers an unknown path with zeros" do
      roll_up_page(today - 1, "/writing/hello", views: 4)

      expect(read_page("/nowhere").fetch("totals")).to eq("views" => 0, "visitors" => 0, "read_seconds" => 0,
                                                          "reach" => 0)
    end

    it "gives no since_publish for a page that is not a post" do
      roll_up_page(today - 1, "/about", views: 4)

      expect(read_page("/about")).not_to have_key("since_publish")
    end

    it "gives no since_publish for a draft's path" do
      create(:post, :draft, slug: "unsent")

      expect(read_page("/writing/unsent")).not_to have_key("since_publish")
    end

    describe "a published post" do
      before do
        create(:post, :published, slug: "part-two", published_at: late_evening(today - 3))
        roll_up_page(today - 3, "/writing/part-two", views: 4)
        roll_up_page(today - 2, "/writing/part-two", views: 8)
      end

      it "numbers the days from the Chicago day it went out" do
        series = [
          { "day" => 1, "date" => (today - 3).iso8601, **page_day(4) },
          { "day" => 2, "date" => (today - 2).iso8601, **page_day(8) },
        ]

        expect(read_page("/writing/part-two", from: today - 5, to: today - 2).fetch("since_publish")).to eq(series)
      end

      it "keeps counting from day 1 when the range starts later" do
        expect(read_page("/writing/part-two", from: today - 2, to: today - 2).fetch("since_publish").first)
          .to include("day" => 2, "date" => (today - 2).iso8601)
      end
    end
  end

  describe "read_analytics hours and since" do
    let(:day) { today - 1 }

    def at(hour, minute = 0, on: day) = Blog::TimeZone.local_time(on.year, on.month, on.day, hour, minute)

    def hour(time) = Blog::TimeZone.local(time).iso8601

    def read_raw(from: day, to: day, **) = mcp_answer("read_analytics", from: from.iso8601, to: to.iso8601, **)

    def view(time, path: "/writing/hello", visitor_hash: nil)
      attrs = { path:, occurred_at: time, read_seconds: 10 }
      create(:analytics_event, **attrs, **(visitor_hash ? { visitor_hash: } : {}))
    end

    it "gives the views and visitors of each Chicago hour that had a view, oldest first" do
      2.times { view(at(9, 15), visitor_hash: "a" * 64) }
      [at(9, 45), at(14, 5)].each { view(it) }
      busy = { "hour" => hour(at(9)), "views" => 3, "visitors" => 2 }

      expect(read_raw.fetch("hours")).to eq([busy, { "hour" => hour(at(14)), "views" => 1, "visitors" => 1 }])
    end

    it "keeps apart the two hours a clock repeats when daylight saving ends" do
      fall_back = (today..(today + 366)).find { it.month == 11 && it.sunday? && it.mday <= 7 }
      [0, 3_600].each { view(at(1, 30, on: fall_back) + it) }

      hours = read_raw(from: fall_back, to: fall_back).fetch("hours").map { it.fetch("hour") }

      expect(hours).to eq(%w[-05:00 -06:00].map { "#{fall_back.iso8601}T01:00:00#{it}" })
    end

    it "counts one page's hours alone" do
      view(at(9))
      view(at(10), path: "/writing/other")

      expect(read_raw(path: "/writing/hello").fetch("hours").map { it.fetch("hour") }).to eq([hour(at(9))])
    end

    it "gives no since without one" do
      expect(read_raw).not_to have_key("since")
    end

    describe "since" do
      before do
        view(at(9))
        2.times { view(at(15), path: "/writing/late") }
        view(at(16))
      end

      it "counts only the views from that time" do
        expect(read_raw(since: at(12).iso8601).fetch("since"))
          .to include("at" => hour(at(12)), "views" => 3, "visitors" => 3, "read_seconds" => 30)
      end

      it "starts the hours there" do
        expect(read_raw(since: at(12).iso8601).fetch("hours").map { it.fetch("hour") })
          .to eq([hour(at(15)), hour(at(16))])
      end

      it "ranks the paths viewed since then" do
        expect(read_raw(since: at(12).iso8601).fetch("since").fetch("paths"))
          .to eq([{ "path" => "/writing/late", "views" => 2, "visitors" => 2 },
                  { "path" => "/writing/hello", "views" => 1, "visitors" => 1 }])
      end

      it "reads a time with no offset as Chicago time" do
        expect(read_raw(since: "#{day.iso8601}T15:30").fetch("since")).to include("views" => 1)
      end

      it "counts one page alone, with no paths" do
        expect(read_raw(since: at(12).iso8601, path: "/writing/hello").fetch("since"))
          .to eq("at" => hour(at(12)), "views" => 1, "visitors" => 1, "read_seconds" => 10)
      end

      it "stops at the end of the range" do
        view(at(9, on: today))

        expect(read_raw(since: at(12).iso8601).fetch("since")).to include("views" => 3)
      end
    end

    it "refuses a since it cannot read" do
      expect(mcp_text("read_analytics", from: day.iso8601, to: day.iso8601, since: "this morning"))
        .to eq(MCP::Tools::ReadAnalytics::SINCE_REFUSAL)
    end

    describe "a range older than the raw visits" do
      let(:old) { today - 120 }

      before { roll_up(old, views: 9, visitors: 4) }

      it "refuses the hours and still gives the days", :aggregate_failures do
        answer = read_raw(from: old, to: today)

        expect(answer).to include("refused" => MCP::Tools::ReadAnalytics::RAW_REFUSAL)
        expect(answer).not_to have_key("hours")
        expect(answer.fetch("totals")).to include("views" => 9)
      end

      it "refuses a since older than the raw visits", :aggregate_failures do
        answer = read_raw(from: old, to: today, since: Blog::TimeZone.day_start(old).iso8601)

        expect(answer).to include("refused" => MCP::Tools::ReadAnalytics::RAW_REFUSAL)
        expect(answer).not_to have_key("since")
        expect(answer.fetch("days").first).to include("views" => 9)
      end

      it "serves the hours from a since inside the raw visits" do
        view(at(9))

        expect(read_raw(from: old, to: day, since: at(8).iso8601).fetch("hours").length).to eq(1)
      end
    end
  end

  describe "read_analytics read_spread" do
    let(:day) { today - 1 }

    def read_spread(from: day, to: day, **)
      mcp_answer("read_analytics", from: from.iso8601, to: to.iso8601, **).fetch("read_spread")
    end

    def view(read_seconds, path: "/writing/hello", hour: 9)
      occurred_at = Blog::TimeZone.local_time(day.year, day.month, day.day, hour, 0)
      create(:analytics_event, path:, read_seconds:, occurred_at:)
    end

    def views(spread) = spread.fetch("buckets").to_h { [[it.fetch("from"), it.fetch("to")], it.fetch("views")] }

    it "counts each view under the bucket its read time falls in" do
      [0, 0, 5, 9, 10, 45, 90, 200, 400, 1_200].each { view(it) }

      expect(views(read_spread)).to eq(
        [0, 0] => 2, [1, 9] => 2, [10, 29] => 1, [30, 59] => 1, [60, 119] => 1, [120, 299] => 1,
        [300, 599] => 1, [600, 1_200] => 1,
      )
    end

    it "keeps the views with no read out of the median" do
      [0, 0, 0, 10, 20, 90].each { view(it) }

      expect(read_spread.fetch("median")).to eq(20.0)
    end

    it "gives the middle of the two middle reads for an even count" do
      [10, 20, 30, 41].each { view(it) }

      expect(read_spread.fetch("median")).to eq(25.0)
    end

    it "gives no median when no view read", :aggregate_failures do
      2.times { view(0) }

      expect(read_spread.fetch("median")).to be_nil
      expect(views(read_spread).fetch([0, 0])).to eq(2)
    end

    it "spreads one page alone" do
      view(30)
      view(300, path: "/writing/other")

      expect(read_spread(path: "/writing/hello").fetch("median")).to eq(30.0)
    end

    it "counts only the views from since" do
      view(30)
      view(300, hour: 15)

      since = Blog::TimeZone.local_time(day.year, day.month, day.day, 12, 0).iso8601

      expect(read_spread(since:).fetch("median")).to eq(300.0)
    end

    it "leaves out the days outside the range" do
      view(30)

      expect(read_spread(from: today, to: today).fetch("buckets").sum { it.fetch("views") }).to eq(0)
    end

    it "refuses a range older than the raw visits and still gives the days", :aggregate_failures do
      roll_up(today - 120, views: 9, visitors: 4)
      answer = mcp_answer("read_analytics", from: (today - 120).iso8601, to: today.iso8601)

      expect(answer).to include("refused" => MCP::Tools::ReadAnalytics::RAW_REFUSAL)
      expect(answer).not_to have_key("read_spread")
      expect(answer.fetch("totals")).to include("views" => 9)
    end
  end
end

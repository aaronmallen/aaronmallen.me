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

      expect(read.fetch("totals")).to eq("views" => 15, "visitors" => 6, "read_seconds" => 150)
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
        expect(read.fetch("totals")).to eq("views" => 7, "visitors" => 5, "read_seconds" => 166)
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

    it "refuses a day it cannot read" do
      expect(mcp_text("read_analytics", from: "last week", to: today.iso8601))
        .to eq("give from and to as days, such as 2026-01-01")
    end

    it "refuses a range that runs backwards" do
      expect(mcp_text("read_analytics", from: today.iso8601, to: (today - 1).iso8601)).to eq("from comes after to")
    end
  end
end

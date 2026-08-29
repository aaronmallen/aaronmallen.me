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

    it "counts today from the visits before they roll up" do
      create(:analytics_event, path: "/writing/today", referrer_host: "news.example", country_code: "US")

      expect(read.fetch("paths").map { it.fetch("path") }).to eq(%w[/writing/today])
    end

    it "puts today's visits on today" do
      create(:analytics_event)

      expect(read.fetch("days").last).to eq("day" => today.iso8601, "views" => 1, "visitors" => 1)
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

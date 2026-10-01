# frozen_string_literal: true

RSpec.describe Analytics::Queries::SummaryBetween do
  let(:rolled) { today - 1 }
  let(:top_rows) { described_class::TOP_ROWS }

  def hosts = summary.fetch(:referrers).map { it[:host] }

  def paths = summary.fetch(:paths).map { it[:path] }

  def summary = Analytics::Slice["queries.summary_between"].call(from: rolled, to: today)

  def today = Blog::TimeZone.today

  before do
    create(:analytics_rollup, day: rolled, views: 1_000, visitors: 500)
    (top_rows + 1).times do |n|
      create(:analytics_rollup_path, day: rolled, path: "/writing/rolled-#{n}", views: n + 2, visitors: 1, bounces: 0)
      create(:analytics_rollup_referrer, day: rolled, host: "rolled-#{n}.example", views: n + 2, visitors: n + 2)
    end
  end

  it "keeps no more than the top rows of paths" do
    expect(paths.length).to eq(top_rows)
  end

  it "leaves out the path with the fewest views" do
    expect(paths).not_to include("/writing/rolled-0")
  end

  it "keeps no more than the top rows of referrers" do
    expect(hosts.length).to eq(top_rows)
  end

  it "leaves out the referrer with the fewest visitors" do
    expect(hosts).not_to include("rolled-0.example")
  end

  describe "with today's visits" do
    before do
      (top_rows + 3).times do
        create(:analytics_event, path: "/writing/fresh", referrer_host: "fresh.example")
      end
    end

    it "ranks a path from today's visits among the rolled up ones" do
      expect(paths.first).to eq("/writing/fresh")
    end

    it "ranks a referrer from today's visits among the rolled up ones" do
      expect(hosts.first).to eq("fresh.example")
    end

    it "still keeps no more than the top rows", :aggregate_failures do
      expect(paths.length).to eq(top_rows)
      expect(hosts.length).to eq(top_rows)
    end
  end
end

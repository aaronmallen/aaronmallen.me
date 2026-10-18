# frozen_string_literal: true

RSpec.describe Analytics::Repos::AnalyticsPageQueries do
  def click(on, path: "/writing/hello", **)
    event = create(:analytics_event, path:, occurred_at: Blog::TimeZone.day_start(on) + (12 * 3_600))
    create(:analytics_click, event_id: event.id, **)
  end

  def clicks(from:, to: today, path: "/writing/hello")
    Analytics::Slice["repos.analytics_page_queries"].clicks_between(path:, from:, to:).map { it.values_at(:link_host, :link_path, :clicks) }
  end

  it "keeps the clicks once the prune takes the day's events" do
    click(today - 91)
    Analytics::Slice["jobs.roll_up_analytics"].perform

    expect(clicks(from: today - 91)).to eq([["docs.example", "/guide", 1]])
  end

  it "ranks each page list from a rollup and the summary field the roll up fills it from" do
    ranked = described_class::RANKED.values.to_h { [it.fetch(:rollup), it.fetch(:summary)] }

    expect(Analytics::Repos::AnalyticsRollupMutations::ROWS).to include(ranked)
  end
end

# frozen_string_literal: true

RSpec.describe Analytics::Queries::ClicksBetween do
  let(:today) { Blog::TimeZone.today }

  def click(on, path: "/writing/hello", **)
    event = create(:analytics_event, path:, occurred_at: Blog::TimeZone.day_start(on) + (12 * 3_600))
    create(:analytics_click, event_id: event.id, **)
  end

  def clicks(from:, to: today, path: "/writing/hello")
    Analytics::Slice["queries.clicks_between"].call(path:, from:, to:).map { it.values_at(:link_host, :link_path, :clicks) }
  end

  it "keeps the clicks once the prune takes the day's events" do
    click(today - 120)
    Analytics::Slice["jobs.roll_up_analytics"].perform

    expect(clicks(from: today - 120)).to eq([["docs.example", "/guide", 1]])
  end
end

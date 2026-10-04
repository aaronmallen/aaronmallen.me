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

  def rolled(on, clicks:, path: "/writing/hello", link_host: "docs.example", link_path: "/guide")
    create(:analytics_rollup_click, day: create(:analytics_rollup, day: on).day, path:, link_host:, link_path:, clicks:)
  end

  it "sums a post's rolled up clicks on each link in the range" do
    rolled(today - 3, clicks: 4)
    rolled(today - 2, clicks: 2)
    rolled(today - 9, clicks: 7)

    expect(clicks(from: today - 3)).to eq([["docs.example", "/guide", 6]])
  end

  it "reads today live beside the rolled up days" do
    rolled(today - 1, clicks: 4)
    click(today)

    expect(clicks(from: today - 1)).to eq([["docs.example", "/guide", 5]])
  end

  it "lists the links most clicked first" do
    rolled(today - 1, clicks: 1, link_path: "/a")
    rolled(today - 2, clicks: 3, link_host: "code.example", link_path: "/b")
    2.times { click(today, link_path: "/c") }

    expect(clicks(from: today - 2).map { it.last(2) }).to eq([["/b", 3], ["/c", 2], ["/a", 1]])
  end

  it "leaves out another post's clicks" do
    rolled(today - 1, clicks: 4, path: "/writing/other")
    click(today, path: "/writing/other")

    expect(clicks(from: today - 1)).to be_empty
  end

  it "keeps the clicks once the prune takes the day's events" do
    click(today - 120)
    Analytics::Slice["jobs.roll_up_analytics"].perform

    expect(clicks(from: today - 120)).to eq([["docs.example", "/guide", 1]])
  end
end

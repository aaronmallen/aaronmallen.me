# frozen_string_literal: true

RSpec.describe Analytics::Operations::RankRows do
  let(:rank_rows) { Analytics::Slice["operations.rank_rows"] }

  def row(source, views:, visitors:) = { source:, views:, visitors:, path: nil }

  it "sums the figures of every row that shares a key" do
    rows = [row("feed", views: 4, visitors: 2), row("feed", views: 3, visitors: 1)]

    expect(rank_rows.call(rows, key: :source)).to eq([{ source: "feed", views: 7, visitors: 3 }])
  end

  it "ranks by most visitors, then most views, then key" do
    figures = { "reddit" => [5, 2], "mastodon" => [9, 2], "bluesky" => [5, 2], "feed" => [1, 4] }
    rows = figures.map { |source, (views, visitors)| row(source, views:, visitors:) }

    expect(rank_rows.call(rows, key: :source).map { it.fetch(:source) }).to eq(%w[feed mastodon bluesky reddit])
  end

  it "ranks a missing key as an empty name" do
    rows = [row("feed", views: 2, visitors: 1), row(nil, views: 2, visitors: 1)]

    expect(rank_rows.call(rows, key: :source).map { it.fetch(:source) }).to eq([nil, "feed"])
  end

  it "sums only the figures it is given" do
    rows = [{ host: "a.example", views: 2, visitors: 1, bounces: 1 }]

    expect(rank_rows.call(rows, key: :host, figures: %i[views visitors]).first.keys)
      .to eq(%i[host views visitors])
  end

  it "keeps an unknown figure unknown and ranks it last" do
    rows = [{ host: "a.example", views: 9, visitors: nil }, { host: "b.example", views: 1, visitors: 1 }]

    expect(rank_rows.call(rows, key: :host)).to eq(
      [{ host: "b.example", views: 1, visitors: 1 }, { host: "a.example", views: 9, visitors: nil }],
    )
  end

  it "ranks by the figure it is given" do
    rows = [{ path: "/a", views: 1, visitors: 1 }, { path: "/b", views: 5, visitors: 0 }]

    expect(rank_rows.call(rows, key: :path, by: :views).map { it.fetch(:path) }).to eq(%w[/b /a])
  end

  it "merges on every column of a compound key" do
    rows = [["/x", 1], ["/y", 1], ["/x", 2]].map { |link_path, clicks| { link_host: "a.example", link_path:, clicks: } }

    expect(rank_rows.call(rows, key: %i[link_host link_path], figures: %i[clicks], by: :clicks)).to eq(
      [{ link_host: "a.example", link_path: "/x", clicks: 3 }, { link_host: "a.example", link_path: "/y", clicks: 1 }],
    )
  end

  it "names a merged row after its last named row" do
    rows = ["Old", "New", nil].map { |title| { path: "/a", views: 1, visitors: 1, title: } }

    expect(rank_rows.call(rows, key: :path, named: :title).first.fetch(:title)).to eq("New")
  end
end

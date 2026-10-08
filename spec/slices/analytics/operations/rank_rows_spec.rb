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
end

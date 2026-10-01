# frozen_string_literal: true

RSpec.describe "Creating the per-page referrer and country rollups", type: :migration do
  let(:gateway) { Analytics::Slice["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }
  let(:rolled) { Blog::TimeZone.today - 3 }
  let(:today) { Blog::TimeZone.today }

  def countries(day) = rows(:analytics_rollup_page_countries, :country_code, day)

  def event(visitor, host, country, on: rolled, path: "/writing/hello")
    occurred_at = Blog::TimeZone.day_start(on) + 60

    db[:analytics_events].insert(
      path:,
      visitor_hash: visitor * 64,
      address_hash: visitor * 64,
      referrer_host: host,
      country_code: country,
      occurred_at:,
    )
  end

  def migrate(target = nil)
    path = Hanami.app.root.join("config/db/migrate").to_s

    ROM::SQL.with_gateway(gateway) { Sequel::Migrator.run(db, path, **{ target: }.compact) }
  end

  def referrers(day) = rows(:analytics_rollup_page_referrers, :host, day)

  def roll_back = migrate(20_261_001_000_067)

  def rows(table, key, day)
    db[table].where(day:).order(:path, key).select_map([:path, key, :views, :visitors])
  end

  before do
    roll_back
    db[:analytics_rollups].insert(day: rolled, views: 5, visitors: 3)
    event("a", "news.example", "US")
    event("a", "news.example", "US")
    event("b", "news.example", "JP")
    event("a", nil, nil)
    event("c", "news.example", "US", path: "/writing/other")
    event("a", "news.example", "US", on: today)
    migrate
  end

  it "fills each page's referrers from the raw visits of a rolled up day" do
    hello = [["/writing/hello", "news.example", 3, 2], ["/writing/hello", nil, 1, 1]]

    expect(referrers(rolled)).to eq([*hello, ["/writing/other", "news.example", 1, 1]])
  end

  it "fills each page's countries from the raw visits of a rolled up day" do
    hello = [["/writing/hello", "JP", 1, 1], ["/writing/hello", "US", 2, 1], ["/writing/hello", nil, 1, 1]]

    expect(countries(rolled)).to eq([*hello, ["/writing/other", "US", 1, 1]])
  end

  it "leaves a day that has not rolled up for the nightly rollup", :aggregate_failures do
    expect(referrers(today)).to eq([])
    expect(countries(today)).to eq([])
  end

  it "refuses more visitors than views" do
    expect { db[:analytics_rollup_page_referrers].where(day: rolled, host: nil).update(visitors: 2) }
      .to raise_error(Sequel::CheckConstraintViolation, /analytics_rollup_page_referrers_counts_check/)
  end

  it "drops the tables on the way down", :aggregate_failures do
    roll_back

    expect(db.table_exists?(:analytics_rollup_page_referrers)).to be(false)
    expect(db.table_exists?(:analytics_rollup_page_countries)).to be(false)
  end
end

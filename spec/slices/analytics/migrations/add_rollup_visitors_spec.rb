# frozen_string_literal: true

RSpec.describe "Adding visitors to the referrer and country rollups", type: :migration do
  let(:gateway) { Analytics::Slice["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }
  let(:recent) { Blog::TimeZone.today - 3 }
  let(:old) { Blog::TimeZone.today - 120 }

  def countries(day)
    db[:analytics_rollup_countries].where(day:).order(:country_code).select_map(%i[country_code visitors])
  end

  def event(visitor, host, country)
    occurred_at = Blog::TimeZone.day_start(recent) + 60

    db[:analytics_events].insert(
      path: "/writing/hello",
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

  def referrers(day) = db[:analytics_rollup_referrers].where(day:).order(:host).select_map(%i[host visitors])

  def roll_back = migrate(20_260_929_000_048)

  def rollup(day, referrers:, countries:)
    db[:analytics_rollups].insert(day:, views: 9, visitors: 3)
    referrers.each { |host, views| db[:analytics_rollup_referrers].insert(day:, host:, views:) }
    countries.each { |country_code, views| db[:analytics_rollup_countries].insert(day:, country_code:, views:) }
  end

  before do
    roll_back
    rollup(recent, referrers: { "news.example" => 3, nil => 1 }, countries: { "US" => 3, "JP" => 1 })
    rollup(old, referrers: { "news.example" => 5 }, countries: { "US" => 5 })
    event("a", "news.example", "US")
    event("a", "news.example", "US")
    event("b", "news.example", "US")
    event("a", nil, "JP")
    migrate
  end

  it "counts each referrer's distinct visitors on a day that still has events" do
    expect(referrers(recent)).to eq([["news.example", 2], [nil, 1]])
  end

  it "counts each country's distinct visitors on a day that still has events" do
    expect(countries(recent)).to eq([["JP", 1], ["US", 2]])
  end

  it "leaves a day past the event window with no visitor count", :aggregate_failures do
    expect(referrers(old)).to eq([["news.example", nil]])
    expect(countries(old)).to eq([["US", nil]])
  end

  it "refuses more visitors than views" do
    expect { db[:analytics_rollup_referrers].where(day: recent, host: nil).update(visitors: 2) }
      .to raise_error(Sequel::CheckConstraintViolation, /analytics_rollup_referrers_visitors_check/)
  end

  it "refuses a negative visitor count" do
    expect { db[:analytics_rollup_countries].where(day: recent).update(visitors: -1) }
      .to raise_error(Sequel::CheckConstraintViolation, /analytics_rollup_countries_visitors_check/)
  end

  it "drops the counts on the way down", :aggregate_failures do
    roll_back

    expect(db[:analytics_rollup_referrers].columns).not_to include(:visitors)
    expect(db[:analytics_rollup_countries].columns).not_to include(:visitors)
  end
end

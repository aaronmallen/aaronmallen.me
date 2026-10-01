# frozen_string_literal: true

RSpec.describe "Adding scroll depth to analytics events", type: :migration do
  let(:gateway) { Analytics::Slice["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }

  def depths = db[:analytics_events].order(:id).select_map(:scroll_depth)

  def event(visitor)
    db[:analytics_events].insert(path: "/writing/hello", visitor_hash: visitor * 64, address_hash: visitor * 64)
  end

  def migrate(target = nil)
    path = Hanami.app.root.join("config/db/migrate").to_s

    ROM::SQL.with_gateway(gateway) { Sequel::Migrator.run(db, path, **{ target: }.compact) }
  end

  def roll_back = migrate(20_261_001_000_069)

  before do
    roll_back
    event("a")
    migrate
  end

  it "leaves the views stored before it with no depth and starts later ones at none" do
    event("b")

    expect(depths).to eq([nil, 0])
  end

  it "refuses a depth that is no milestone" do
    expect { db[:analytics_events].update(scroll_depth: 30) }.to raise_error(Sequel::CheckConstraintViolation)
  end

  it "refuses a rolled up depth that is no milestone" do
    db[:analytics_rollups].insert(day: Blog::TimeZone.today, views: 1, visitors: 1)

    expect { db[:analytics_rollup_scroll_depths].insert(day: Blog::TimeZone.today, path: "/a", scroll_depth: 30) }
      .to raise_error(Sequel::CheckConstraintViolation)
  end

  it "drops the column and the table on the way down", :aggregate_failures do
    roll_back

    expect(db[:analytics_events].columns).not_to include(:scroll_depth)
    expect(db.table_exists?(:analytics_rollup_scroll_depths)).to be(false)
  end
end

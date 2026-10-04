# frozen_string_literal: true

RSpec.describe "Adding read-throughs to the path rollups", type: :migration do
  let(:gateway) { Analytics::Slice["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }
  let(:day) { Blog::TimeZone.today - 3 }

  def migrate(target = nil)
    path = Hanami.app.root.join("config/db/migrate").to_s

    ROM::SQL.with_gateway(gateway) { Sequel::Migrator.run(db, path, **{ target: }.compact) }
  end

  def roll_back = migrate(20_261_003_000_097)

  def rows = db[:analytics_rollup_paths].where(day:)

  before do
    roll_back
    db[:analytics_rollups].insert(day:, views: 9, visitors: 3)
    db[:analytics_rollup_paths].insert(day:, path: "/writing/hello", views: 9, visitors: 3)
    migrate
  end

  it "leaves a day rolled up before it with no count" do
    expect(rows.select_map(:read_throughs)).to eq([nil])
  end

  it "refuses more read-throughs than visitors" do
    expect { rows.update(read_throughs: 4) }
      .to raise_error(Sequel::CheckConstraintViolation, /analytics_rollup_paths_read_throughs_check/)
  end

  it "refuses a negative count" do
    expect { rows.update(read_throughs: -1) }
      .to raise_error(Sequel::CheckConstraintViolation, /analytics_rollup_paths_read_throughs_check/)
  end

  it "drops the count on the way down" do
    roll_back

    expect(db[:analytics_rollup_paths].columns).not_to include(:read_throughs)
  end
end

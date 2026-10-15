# frozen_string_literal: true

RSpec.describe "Backfilling the analytics rollup hours", :frozen_clock, type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:day) { Blog::TimeZone.today - 1 }
  let(:path) { Hanami.app.root.join("config/db/migrate/20261015120010_backfill_analytics_rollup_hours.rb") }

  def at(on, hour) = Blog::TimeZone.day_start(on) + (hour * 3_600)

  def backfill
    ROM::SQL.with_gateway(Hanami.app["db.rom"].gateways[:default]) { load path.to_s }
    Sequel::Migration.descendants.last.apply(db, :up)
  end

  def hours(on = day) = db[:analytics_rollup_hours].where(day: on).order(:hour).select_map(%i[hour visitors])

  it "counts each rolled up day's visitors in each of its hours" do
    create(:analytics_rollup, day:)
    2.times { create(:analytics_event, occurred_at: at(day, 9)) }
    create(:analytics_event, occurred_at: at(day, 21))

    backfill

    expect(hours).to eq([[9, 2], [21, 1]])
  end

  it "counts a visitor twice in one hour once" do
    create(:analytics_rollup, day:)
    2.times { create(:analytics_event, occurred_at: at(day, 9), visitor_hash: "a" * 64) }

    backfill

    expect(hours).to eq([[9, 1]])
  end

  it "leaves out a day not rolled up yet" do
    create(:analytics_event, occurred_at: at(Blog::TimeZone.today, 9))

    backfill

    expect(db[:analytics_rollup_hours].count).to eq(0)
  end
end

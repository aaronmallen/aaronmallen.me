# frozen_string_literal: true

require "digest"

RSpec.describe Analytics::Queries::ReadThroughsBetween do
  let(:reader) { Digest::SHA256.hexdigest("reader") }
  let(:today) { Blog::TimeZone.today }

  def read(on, path: "/writing/hello", visitor_hash: reader)
    create(
      :analytics_event,
      path:,
      visitor_hash:,
      scroll_depth: 75,
      read_seconds: 30,
      occurred_at: Blog::TimeZone.day_start(on) + (12 * 3_600),
    )
  end

  def read_throughs(from:, to: today) = Analytics::Slice["queries.read_throughs_between"].call(from:, to:)

  def roll_up = Analytics::Slice["jobs.roll_up_analytics"].perform

  def rolled(on, path:, read_throughs:)
    create(:analytics_rollup_path, day: create(:analytics_rollup, day: on).day, path:, read_throughs:)
  end

  it "sums each path's rolled up days in the range" do
    rolled(today - 3, path: "/writing/hello", read_throughs: 4)
    rolled(today - 2, path: "/writing/hello", read_throughs: 2)
    rolled(today - 9, path: "/writing/hello", read_throughs: 7)

    expect(read_throughs(from: today - 3)).to eq("/writing/hello" => 6)
  end

  it "reads today live beside the rolled up days" do
    rolled(today - 1, path: "/writing/hello", read_throughs: 4)
    read(today)
    read(today, path: "/writing/other")

    expect(read_throughs(from: today - 1)).to eq("/writing/hello" => 5, "/writing/other" => 1)
  end

  it "counts a reader once a day but again the next day" do
    2.times { read(today) }
    read(today - 1)
    roll_up
    read(today)

    expect(read_throughs(from: today - 1)).to eq("/writing/hello" => 2)
  end

  it "keeps the count once the prune takes the day's events", :aggregate_failures do
    read(today - 120)
    roll_up

    expect(Analytics::Slice["repos.analytics_event_repo"].oldest_day).to be_nil
    expect(read_throughs(from: today - 120)).to eq("/writing/hello" => 1)
  end

  it "leaves out a path no one read through" do
    rolled(today - 1, path: "/writing/hello", read_throughs: 0)
    create(:analytics_event, path: "/writing/other", scroll_depth: 25)

    expect(read_throughs(from: today - 1)).to be_empty
  end

  it "counts nothing for a day rolled up before the site counted read-throughs" do
    rolled(today - 1, path: "/writing/hello", read_throughs: nil)

    expect(read_throughs(from: today - 1)).to be_empty
  end
end

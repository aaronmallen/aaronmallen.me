# frozen_string_literal: true

RSpec.describe Social::Operations::MeasureParts do
  def counted(bodies, targets) = measure(bodies, targets).map { it.transform_values(&:counted) }

  def measure(bodies, targets) = Social::Slice["operations.measure_parts"].call(bodies, targets)

  it "gives each part its count and limit on each network it targets" do
    hi = { "mastodon" => { count: 2, limit: 500 }, "bluesky" => { count: 2, limit: 300 } }
    there = { "mastodon" => { count: 5, limit: 500 }, "bluesky" => { count: 5, limit: 300 } }

    expect(counted(%w[hi there], %w[mastodon bluesky])).to eq([hi, there])
  end

  it "leaves out a network the post does not target" do
    expect(measure(%w[hi], %w[bluesky]).first.keys).to eq(%w[bluesky])
  end

  it "counts a link the way each network does once it is tagged" do
    lengths = measure(["https://aaronmallen.me/a"], %w[mastodon bluesky]).first

    expect(lengths.transform_values(&:count)).to eq("mastodon" => 23, "bluesky" => 36)
  end

  it "counts a mention as it reads on each network" do
    create(:person, :bluesky, key: "ada", mastodon_handle: "@ada@ruby.social", bluesky_handle: "ada.bsky.social")
    lengths = measure(["@{ada}"], %w[mastodon bluesky]).first

    expect(lengths.transform_values(&:count)).to eq("mastodon" => 4, "bluesky" => 16)
  end

  it "flags a part that fits Mastodon but not Bluesky", :aggregate_failures do
    lengths = measure(["a" * 400], %w[mastodon bluesky]).first

    expect(lengths.fetch("mastodon").over).to be(false)
    expect(lengths.fetch("bluesky")).to have_attributes(part: 1, count: 400, limit: 300, over: true)
  end
end

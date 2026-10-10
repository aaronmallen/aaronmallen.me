# frozen_string_literal: true

RSpec.describe Social::Operations::CheckNetworkFit do
  def fits?(bodies, targets) = Social::Slice["operations.check_network_fit"].call(bodies, targets)

  it "passes text that fits every network it targets" do
    expect(fits?(%w[hi there], %w[mastodon bluesky])).to be(true)
  end

  it "passes when there is no network to fit" do
    expect(fits?(["a" * 600], [])).to be(true)
  end

  it "refuses text that fits Mastodon but not Bluesky", :aggregate_failures do
    expect(fits?(["a" * 400], %w[mastodon])).to be(true)
    expect(fits?(["a" * 400], %w[mastodon bluesky])).to be(false)
  end

  it "refuses when any one part runs over" do
    expect(fits?(["hi", "a" * 301], %w[bluesky])).to be(false)
  end

  it "measures a mention as it reads once expanded for the network" do
    create(:person, :bluesky, key: "ada", mastodon_handle: "@ada@ruby.social", bluesky_handle: "ada.bsky.social")

    expect(fits?(["#{'a' * 285} @{ada}"], %w[bluesky])).to be(false)
  end
end

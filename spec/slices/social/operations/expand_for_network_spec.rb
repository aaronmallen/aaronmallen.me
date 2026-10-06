# frozen_string_literal: true

RSpec.describe Social::Operations::ExpandForNetwork do
  def expand(bodies, network) = Social::Slice["operations.expand_for_network"].call(bodies, network)

  it "tags the site's links with the network and leaves other links alone" do
    expansion = expand(["Read https://aaronmallen.me/a and https://example.com/b"], "bluesky").first

    expect(expansion.text).to eq("Read https://aaronmallen.me/a?ref=bluesky and https://example.com/b")
  end

  it "expands mentions to the network's handle" do
    create(:person, key: "ada", mastodon_handle: "@ada@ruby.social")

    expect(expand(["Hi @{ada}"], "mastodon").first.text).to eq("Hi @ada@ruby.social")
  end

  it "keeps the mention offsets for the text the network gets" do
    create(:person, :bluesky, key: "ada", bluesky_handle: "ada.bsky.social")
    expansion = expand(["https://aaronmallen.me @{ada}"], "bluesky").first

    expect(expansion.text.byteslice(expansion.mentions.first.byte_start...expansion.mentions.first.byte_end))
      .to eq("@ada.bsky.social")
  end

  it "expands each body in order" do
    texts = expand(["one https://aaronmallen.me/1", "two https://aaronmallen.me/2"], "mastodon").map(&:text)

    expect(texts).to eq(["one https://aaronmallen.me/1?ref=mastodon", "two https://aaronmallen.me/2?ref=mastodon"])
  end
end

# frozen_string_literal: true

RSpec.describe Social::Operations::ExpandForNetwork do
  def expand(bodies, network, **) = Social::Slice["operations.expand_for_network"].call(bodies, network, **)

  def short_links = Shares::Slice["relations.short_links"]

  it "tags the site's links with the network and counts other links at a short link's length" do
    expansion = expand(["Read https://aaronmallen.me/a and https://example.com/b"], "bluesky").first

    expect(expansion.text).to eq("Read https://aaronmallen.me/a?ref=bluesky and http://shares.localhost/xxxxx")
  end

  it "makes no short link and fetches no title unless asked", :aggregate_failures do
    expand(["Read https://example.com/b"], "bluesky")

    expect(short_links.count).to eq(0)
    expect(Shares::Jobs::FetchShortLinkTitle.jobs).to be_empty
  end

  it "counts a link I shortened before at its own code" do
    Shares::Slice["operations.create_short_link"].call(destination: "https://example.com/b", code: "my-talk")

    expect(expand(["Read https://example.com/b"], "mastodon").first.text).to eq("Read http://shares.localhost/my-talk")
  end

  it "makes a short link when asked and queues a fetch of its title", :aggregate_failures, :commits do
    text = expand(["Read https://example.com/b"], "mastodon", make_links: true).first.text
    link = Shares::Slice["repos.short_link_queries"].by_destination("https://example.com/b")

    expect(Shares::Jobs::FetchShortLinkTitle.jobs.map { it["args"] }).to eq([[link.id]])
    expect(text).to eq("Read http://shares.localhost/#{link.code}")
  end

  it "reuses the short link it made before", :aggregate_failures do
    first = expand(["Read https://example.com/b"], "mastodon", make_links: true).first.text

    expect(expand(["Read https://example.com/b"], "bluesky", make_links: true).first.text).to eq(first)
    expect(short_links.count).to eq(1)
  end

  it "keeps the mention offsets after a link gets shorter" do
    create(:person, :bluesky, key: "ada", bluesky_handle: "ada.bsky.social")
    expansion = expand(["https://example.com/a/long/path @{ada}"], "bluesky", make_links: true).first

    expect(expansion.text.byteslice(expansion.mentions.first.byte_start...expansion.mentions.first.byte_end))
      .to eq("@ada.bsky.social")
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

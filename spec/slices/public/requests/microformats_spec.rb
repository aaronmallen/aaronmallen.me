# frozen_string_literal: true

require "nokogiri"

RSpec.describe "Microformats", type: :request do
  let(:doc) { Nokogiri::HTML5(last_response.body) }
  let(:page) { Capybara.string(last_response.body) }

  def parse(body) = Nokogiri::HTML5(body)

  def publish(slug, **attrs)
    create(:post, :published, slug:, title: slug.capitalize, published_at: Time.utc(2026, 9, 7, 12), **attrs)
  end

  describe "the homepage" do
    let(:profiles) do
      {
        bluesky: { profile_url: "https://bsky.example/ada" },
        github: { profile_url: "https://github.example/ada" },
        mastodon: { profile_url: "https://social.example/@ada" },
      }
    end

    before do
      allow(Hanami.app.settings).to receive_messages(**profiles)
      get "/"
    end

    it "carries one h-card" do
      expect(doc.css(".h-card").size).to eq(1)
    end

    it "names the card and points it at the root", :aggregate_failures do
      link = doc.at_css(".h-card a.p-name.u-url.u-uid")

      expect(link.text).to eq("Aaron Allen")
      expect(link[:href]).to eq("/")
    end

    it "links each profile with rel=me" do
      expect(doc.css(".h-card a.site-footer-link[rel=me]").map { it[:href] })
        .to eq(["https://github.example/ada", "https://bsky.example/ada", "https://social.example/@ada"])
    end

    context "with no profile configured" do
      let(:profiles) { { bluesky: {}, github: {}, mastodon: {} } }

      it "still carries the h-card" do
        expect(doc.css(".h-card").size).to eq(1)
      end

      it "leaves every profile link out" do
        expect(doc.css("a.site-footer-link")).to be_empty
      end
    end
  end

  describe "the index" do
    before do
      publish("hello", tags: %w[ruby], summary: "what it is about", body: "the first part")
      get "/writing"
    end

    it "holds the entries in an h-feed" do
      expect(doc.css(".h-feed > .h-entry").size).to eq(1)
    end

    it "names each entry and links it to the article", :aggregate_failures do
      link = doc.at_css(".h-entry a.p-name.u-url")

      expect(link.text).to eq("Hello")
      expect(link[:href]).to eq("/writing/hello")
    end

    it "dates each entry" do
      expect(doc.at_css(".h-entry time.dt-published")[:datetime]).to eq("2026-09-07T07:00:00-05:00")
    end

    it "summarises each entry" do
      expect(doc.at_css(".h-entry .p-summary").text).to eq("what it is about")
    end
  end

  describe "an article" do
    subject(:entry) { doc.at_css("article.h-entry") }

    before do
      publish("hello", tags: %w[ruby hanami], body: "the body")
      get "/writing/hello"
    end

    it "names the entry" do
      expect(entry.at_css("h1.p-name").text).to eq("Hello")
    end

    it "points the entry at its own url" do
      expect(entry.at_css("data.u-url")[:value]).to eq("/writing/hello")
    end

    it "dates the entry" do
      expect(entry.at_css("time.dt-published")[:datetime]).to eq("2026-09-07T07:00:00-05:00")
    end

    it "holds the body in e-content" do
      expect(entry.at_css(".e-content").text).to include("the body")
    end

    it "marks each tag as a category" do
      expect(entry.css("a.p-category").map(&:text)).to eq(%w[hanami ruby])
    end

    it "credits the author in an h-card", :aggregate_failures do
      author = entry.at_css(".p-author.h-card")

      expect(author[:href]).to eq("/")
      expect(author.at_css(".p-name").text).to eq("Aaron Allen")
    end
  end

  describe "an article that went out on social" do
    let(:urls) { { "bluesky" => "https://bsky.example/ada/1", "mastodon" => "https://social.example/@ada/1" } }

    before do
      social_post = create(:social_post, :posted, post_id: publish("hello").id)
      urls.each do |network, url|
        create(:social_post_delivery, network:, social_post_id: social_post.id, remote_url: url)
      end
      get "/writing/hello"
    end

    it "links each network's post as a u-syndication" do
      links = doc.css("article.h-entry a.u-syndication")

      expect(links.map { it[:href] }).to eq(%w[https://bsky.example/ada/1 https://social.example/@ada/1])
    end

    it "shows each link" do
      expect(page.find(".post-syndication")).to have_text("Also posted on")
        .and have_link("Bluesky", href: "https://bsky.example/ada/1")
        .and have_link("Mastodon", href: "https://social.example/@ada/1")
    end
  end

  describe "an article with an approved reply" do
    subject(:comment) { doc.at_css("article.h-entry .u-comment.h-cite") }

    before do
      target = publish("hello")
      create(
        :webmention, :approved, :reply, post_id: target.id, author_name: "Ada",
                                        source_url: "https://ada.example/reply", excerpt: "Good one",
                                        received_at: Time.utc(2026, 9, 7, 12),
      )
      get "/writing/hello"
    end

    it "points the cite at the source" do
      expect(comment.at_css("a.u-url")[:href]).to eq("https://ada.example/reply")
    end

    it "credits the reply's author in an h-card" do
      expect(comment.at_css(".p-author.h-card .p-name").text).to eq("Ada")
    end

    it "dates the cite" do
      expect(comment.at_css("time.dt-published")[:datetime]).to eq("2026-09-07T07:00:00-05:00")
    end

    it "holds the excerpt in p-content" do
      expect(comment.at_css(".p-content").text).to eq("Good one")
    end
  end

  describe "the author link on an article" do
    subject(:card) { parse(last_response.body).at_css(".h-card a.p-name.u-url.u-uid") }

    let(:author) do
      publish("hello")
      get "/writing/hello"
      parse(last_response.body).at_css("article.h-entry .p-author.h-card")
    end

    before { get author[:href] }

    it "resolves to an h-card on the page it links to" do
      expect(card[:href]).to eq(author[:href])
    end

    it "names the same person" do
      expect(card.text).to eq(author.text.strip)
    end
  end

  it "leaves out the syndication row for an article that has not gone out" do
    publish("hello")
    get "/writing/hello"

    expect(doc.css(".post-syndication")).to be_empty
  end
end

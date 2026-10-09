# frozen_string_literal: true

RSpec.describe "SEO tags", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def canonical = page.find("link[rel='canonical']", visible: :all)[:href]

  def named(name) = page.all("meta[name='#{name}']", visible: :all).map { it[:content] }

  def property(name) = page.all("meta[property='#{name}']", visible: :all).map { it[:content] }

  def publish(**attributes) = create(:post, :published, slug: "hello", title: "Hello", **attributes)

  describe "a page with nothing of its own" do
    before { get "/privacy" }

    it "calls it a website" do
      expect(property("og:type")).to eq(%w[website])
    end

    it "names the site" do
      expect(property("og:site_name")).to eq(["Aaron Allen"])
    end

    it "titles the card with the page, not the whole document title" do
      expect(property("og:title")).to eq(%w[Privacy])
    end

    it "builds the canonical link from the site setting, not the host that asked" do
      expect(canonical).to eq("https://aaronmallen.me/privacy")
    end

    it "points the card at the canonical link" do
      expect(property("og:url")).to eq([canonical])
    end

    it "asks for the large card" do
      expect(named("twitter:card")).to eq(%w[summary_large_image])
    end

    it "shares the site image", :aggregate_failures do
      expect(property("og:image")).to match([a_string_matching(%r{\Ahttps://aaronmallen\.me/assets/share.*\.png\z})])
      expect(named("twitter:image")).to eq(property("og:image"))
    end

    it "describes the site image", :aggregate_failures do
      expect(property("og:image:alt")).to eq(["Aaron Allen's logo: black glasses in a white circle"])
      expect(named("twitter:image:alt")).to eq(property("og:image:alt"))
    end

    it "sizes the site image", :aggregate_failures do
      expect(property("og:image:width")).to eq(%w[1200])
      expect(property("og:image:height")).to eq(%w[630])
    end

    it "emits no description it does not have", :aggregate_failures do
      expect(property("og:description")).to be_empty
      expect(named("description")).to be_empty
    end
  end

  describe "the home page" do
    before { get "/" }

    it "titles the card with the owner" do
      expect(property("og:title")).to eq(["Aaron Allen"])
    end

    it "says what the site is beside the owner in the document title" do
      expect(page.find("title", visible: :all).text).to eq("Writing and projects | Aaron Allen")
    end

    it "roots the canonical link" do
      expect(canonical).to eq("https://aaronmallen.me/")
    end
  end

  describe "the descriptions of the pages" do
    def description_of(path)
      get path
      head = Capybara.string(last_response.body)
      ["[name='description']", "[property='og:description']", "[name='twitter:description']"]
        .map { |tag| head.all("meta#{tag}", visible: :all).map { it[:content] } }
    end

    before { publish(tags: %w[ruby]) }

    let(:descriptions) { %w[/ /about /projects /contact /writing /writing/tags/ruby].to_h { [it, description_of(it)] } }

    it "gives each page one description in the meta, Open Graph and Twitter tags", :aggregate_failures do
      descriptions.each_value do |tags|
        expect(tags).to all(contain_exactly(a_string_matching(/\S/)))
        expect(tags.uniq.size).to eq(1)
      end
    end

    it "gives each page a description of its own" do
      expect(descriptions.values.uniq.size).to eq(descriptions.size)
    end

    it "names the tag on a tag page" do
      expect(descriptions["/writing/tags/ruby"].flatten).to all(include("ruby"))
    end
  end

  describe "an article carrying nothing of its own" do
    before do
      publish(summary: "", body: "The opening paragraph\n\nthe second", tags: %w[ruby hanami],
              published_at: Time.utc(2026, 9, 17, 15, 30), updated_at: Time.utc(2026, 9, 17, 15, 30))
      get "/writing/hello"
    end

    it "calls it an article" do
      expect(property("og:type")).to eq(%w[article])
    end

    it "titles the card with the post" do
      expect(property("og:title")).to eq(%w[Hello])
    end

    it "describes it with the paragraph the blurb infers" do
      expect(property("og:description")).to eq(["The opening paragraph"])
    end

    it "describes it for Twitter too" do
      expect(named("twitter:description")).to eq(["The opening paragraph"])
    end

    it "describes it for search engines too" do
      expect(named("description")).to eq(["The opening paragraph"])
    end

    it "points at its own page on this site" do
      expect(canonical).to eq("https://aaronmallen.me/writing/hello")
    end

    it "dates it" do
      expect(property("article:published_time")).to eq(%w[2026-09-17T15:30:00Z])
    end

    it "says when it last changed" do
      expect(property("article:modified_time")).to eq(%w[2026-09-17T15:30:00Z])
    end

    it "names the author" do
      expect(property("article:author")).to eq(["Aaron Allen"])
    end

    it "tags it" do
      expect(property("article:tag")).to contain_exactly("hanami", "ruby")
    end

    it "shares the site image on the large card", :aggregate_failures do
      expect(property("og:image")).to match([a_string_including("/assets/share")])
      expect(named("twitter:card")).to eq(%w[summary_large_image])
    end
  end

  describe "an article with a long first paragraph and no summary" do
    before do
      publish(summary: "", body: "#{'word ' * 60}\n\nthe second")
      get "/writing/hello"
    end

    it "cuts the description to a length search results show", :aggregate_failures do
      description = named("description").first
      expect(description.length).to eq(160)
      expect(description).to start_with("word word").and end_with("…")
    end

    it "cuts the card descriptions the same way" do
      expect(property("og:description")).to eq(named("description"))
    end
  end

  describe "an article with no summary and no paragraph" do
    before do
      publish(summary: "  ", body: "## Only a heading")
      get "/writing/hello"
    end

    it "emits no empty description", :aggregate_failures do
      expect(named("description")).to be_empty
      expect(property("og:description")).to be_empty
      expect(named("twitter:description")).to be_empty
    end
  end

  describe "an article with a long summary of its own" do
    let(:summary) { "word " * 60 }

    before do
      publish(summary:)
      get "/writing/hello"
    end

    it "keeps the whole summary" do
      expect(named("description")).to eq([summary.strip])
    end
  end

  describe "an article carrying its own social card" do
    before do
      publish(summary: "What it is about", og_title: "On the card",
              og_image_url: "https://example.com/card.png",
              canonical_url: "https://elsewhere.example/hello")
      get "/writing/hello"
    end

    it "prefers the card title" do
      expect(property("og:title")).to eq(["On the card"])
    end

    it "keeps the document title as the post title" do
      expect(page.find("title", visible: :all).text).to eq("Hello | Aaron Allen")
    end

    it "describes it with the summary the post carries" do
      expect(property("og:description")).to eq(["What it is about"])
    end

    it "gives search engines the same summary" do
      expect(named("description")).to eq(["What it is about"])
    end

    it "shows the image" do
      expect(property("og:image")).to eq(["https://example.com/card.png"])
    end

    it "shows the image to Twitter too" do
      expect(named("twitter:image")).to eq(["https://example.com/card.png"])
    end

    it "describes the image with the card title", :aggregate_failures do
      expect(property("og:image:alt")).to eq(["On the card"])
      expect(named("twitter:image:alt")).to eq(["On the card"])
    end

    it "claims no size it does not know", :aggregate_failures do
      expect(property("og:image:width")).to be_empty
      expect(property("og:image:height")).to be_empty
    end

    it "asks for the large card once it has an image" do
      expect(named("twitter:card")).to eq(%w[summary_large_image])
    end

    it "points the canonical link where the post first appeared" do
      expect(canonical).to eq("https://elsewhere.example/hello")
    end

    it "points the card there too" do
      expect(property("og:url")).to eq(["https://elsewhere.example/hello"])
    end
  end

  describe "the projects page" do
    it "takes its image from the first card that carries one" do
      create(:project, og_image_url: nil)
      create(:project, og_image_url: "https://example.com/sai.png")
      get "/projects"

      expect(property("og:image")).to eq(["https://example.com/sai.png"])
    end

    it "skips a private project's image" do
      create(:project, :private, og_image_url: "https://example.com/hidden.png")
      create(:project, og_image_url: "https://example.com/shown.png")
      get "/projects"

      expect(property("og:image")).to eq(["https://example.com/shown.png"])
    end

    it "falls back to the site image when no project carries one" do
      create(:project, og_image_url: nil)
      get "/projects"

      expect(property("og:image")).to match([a_string_including("/assets/share")])
    end

    it "passes over a card whose image is blank" do
      create(:project, og_image_url: "")
      get "/projects"

      expect(property("og:image")).to match([a_string_including("/assets/share")])
    end
  end
end

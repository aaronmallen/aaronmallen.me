# frozen_string_literal: true

RSpec.describe "Structured data", type: :request do
  let(:site) { "https://aaronmallen.me/" }
  let(:owner) { { "@type" => "Person", "@id" => "#{site}#owner", "name" => "Aaron Allen", "url" => site } }

  def publish(**attributes) = create(:post, :published, slug: "hello", title: "Hello", **attributes)

  def structured_data
    scripts = Capybara.string(last_response.body).all("script[type='application/ld+json']", visible: :all)
    scripts.map { JSON.parse(it.text(:all)) }
  end

  describe "a post with nothing of its own" do
    let(:posting) do
      {
        "@context" => "https://schema.org",
        "@type" => "BlogPosting",
        "headline" => "Hello",
        "description" => "The opening paragraph",
        "datePublished" => "2026-09-17T15:30:00Z",
        "dateModified" => "2026-09-18T09:00:00Z",
        "author" => owner,
        "url" => "#{site}writing/hello",
        "mainEntityOfPage" => "#{site}writing/hello",
        "keywords" => %w[ruby],
      }
    end

    before do
      publish(summary: "", body: "The opening paragraph", tags: %w[ruby],
              published_at: Time.utc(2026, 9, 17, 15, 30), updated_at: Time.utc(2026, 9, 18, 9))
      get "/writing/hello"
    end

    it "describes it as a blog post" do
      expect(structured_data).to eq([posting])
    end
  end

  describe "a post with its own card" do
    before do
      publish(summary: "What it is about", title: "</script><b>Hello</b>",
              og_image_url: "https://example.com/card.png", canonical_url: "https://elsewhere.example/hello")
      get "/writing/hello"
    end

    it "carries its image, canonical link and summary" do
      expect(structured_data.first).to include(
        "image" => "https://example.com/card.png",
        "url" => "https://elsewhere.example/hello",
        "description" => "What it is about",
      )
    end

    it "leaves out keywords it does not have" do
      expect(structured_data.first).not_to have_key("keywords")
    end

    it "keeps a title that looks like markup inside the script" do
      expect(structured_data.first["headline"]).to eq("</script><b>Hello</b>")
    end
  end

  describe "the home page" do
    let(:profiles) do
      %w[https://github.com/aaronmallen https://bsky.app/profile/aaronmallen.dev https://ruby.social/@aaronmallen]
    end
    let(:website) do
      { "@type" => "WebSite", "@id" => "#{site}#website", "url" => site, "name" => "Aaron Allen",
        "publisher" => { "@id" => "#{site}#owner" } }
    end

    before { get "/" }

    it "describes the site and its owner with their profiles" do
      expect(structured_data).to eq(
        [{ "@context" => "https://schema.org", "@graph" => [website, owner.merge("sameAs" => profiles)] }],
      )
    end
  end

  describe "a page with no structured data of its own" do
    before { get "/privacy" }

    it "renders none" do
      expect(structured_data).to be_empty
    end
  end
end

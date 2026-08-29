# frozen_string_literal: true

RSpec.describe "Tags", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def publish(slug, minutes_ago, **attrs)
    create(:post, :published, slug:, title: slug.capitalize, published_at: Time.now - (minutes_ago * 60), **attrs)
  end

  it "lists published posts with the tag, newest first" do
    publish("older", 3, tags: %w[ruby])
    publish("newer", 2, tags: %w[hanami ruby])
    get "/writing/tags/ruby"

    expect(page.all(".entry .entry-title").map(&:text)).to eq(%w[Newer Older])
  end

  it "leaves out drafts, scheduled posts and posts without the tag" do
    publish("shown", 2, tags: %w[ruby])
    publish("other", 1, tags: %w[rust])
    %i[draft scheduled].each { create(:post, it, tags: %w[ruby]) }
    get "/writing/tags/ruby"

    expect(page.all(".entry .entry-title").map(&:text)).to eq(%w[Shown])
  end

  it "renders each row the way the index does", :aggregate_failures do
    publish("hello", 1, tags: %w[ruby], summary: "what it is about", body: "the first part")
    get "/writing/tags/ruby"

    expect(page).to have_css(".entry-title a.entry-link[href='/writing/hello']", text: "Hello")
    expect(page).to have_css(".entry-blurb", exact_text: "what it is about")
    expect(page).to have_css(".entry-meta a.post-tag[href='/writing/tags/ruby']")
  end

  it "uses the summary the post carries as the blurb" do
    publish("hello", 1, tags: %w[ruby], summary: "What it is about", body: "the first part")
    get "/writing/tags/ruby"

    expect(page).to have_css(".entry-blurb", exact_text: "What it is about")
  end

  it "names the tag in the heading and title", :aggregate_failures do
    publish("hello", 1, tags: %w[ruby])
    get "/writing/tags/ruby"

    expect(page).to have_css("h1.page-title", text: "Tagged ruby")
    expect(page).to have_title("Tagged ruby | Aaron Allen")
  end

  it "links its own feed in the head" do
    publish("hello", 1, tags: %w[ruby])
    get "/writing/tags/ruby"

    link = page.find("head link[rel='alternate'][type='application/atom+xml']", visible: :all)

    expect([link[:href], link[:title]]).to eq(["/writing/tags/ruby.atom", "Tagged ruby | Aaron Allen"])
  end

  it "finds a tag with a dash in it" do
    publish("hello", 1, tags: %w[open-source])
    get "/writing/tags/open-source"

    expect(page).to have_css(".entry-title", text: "Hello")
  end

  it "names its own address in the canonical link and the card", :aggregate_failures do
    publish("hello", 1, tags: %w[ruby])
    get "/writing/tags/ruby"

    expect(page.find("link[rel='canonical']", visible: :all)[:href]).to eq("https://aaronmallen.me/writing/tags/ruby")
    expect(page.find("meta[property='og:url']", visible: :all)[:content]).to eq("https://aaronmallen.me/writing/tags/ruby")
  end

  { "RUBY" => "another case", "%20ruby" => "padding", "rub%79" => "an escape" }.each do |spelling, difference|
    it "moves a url that spells the tag with #{difference} to the tag's own address", :aggregate_failures do
      publish("hello", 1, tags: %w[ruby])
      get "/writing/tags/#{spelling}"

      expect(last_response.status).to eq(301)
      expect(last_response.location).to eq("/writing/tags/ruby")
    end
  end

  it "returns 404 for a url that is no tag" do
    publish("hello", 1, tags: %w[ruby])
    get "/writing/tags/open%20source"

    expect(last_response).to be_not_found
  end

  it "returns 404 for a tag nothing carries" do
    publish("hello", 1, tags: %w[ruby])
    get "/writing/tags/rust"

    expect(last_response).to be_not_found
  end

  it "serves the site's not found page for a tag nothing carries", :aggregate_failures do
    get "/writing/tags/rust"

    expect(last_response.content_type).to start_with("text/html")
    expect(last_response.body).to eq(Hanami.app.root.join("public/404.html").read)
  end

  it "serves the site's not found page for a url that is no tag" do
    get "/writing/tags/open%20source"

    expect(last_response.body).to eq(Hanami.app.root.join("public/404.html").read)
  end

  %i[draft scheduled].each do |status|
    it "returns 404 for a tag only a #{status} post has" do
      create(:post, status, tags: %w[secret])
      get "/writing/tags/secret"

      expect(last_response).to be_not_found
    end
  end

  it "never shows a journal entry that shares the tag, since the journal is private" do
    publish("hello", 1, tags: %w[ruby])
    create(:journal_entry, body: "a private thought", tags: %w[ruby])
    get "/writing/tags/ruby"

    expect(page).to have_no_text("a private thought")
  end

  it "returns 404 for a tag only a journal entry has" do
    create(:journal_entry, body: "a private thought", tags: %w[secret])
    get "/writing/tags/secret"

    expect(last_response).to be_not_found
  end

  it "never shows a task that shares the tag, since tasks are private" do
    publish("hello", 1, tags: %w[ruby])
    create(:task, :done, title: "clear the gutters", tags: %w[ruby])
    get "/writing/tags/ruby"

    expect(page).to have_no_text("clear the gutters")
  end

  it "returns 404 for a tag only a task has" do
    create(:task, :done, title: "clear the gutters", tags: %w[secret])
    get "/writing/tags/secret"

    expect(last_response).to be_not_found
  end

  it "returns 404 for a tag only an archived project has" do
    create(:project, :archived, tags: %w[secret])
    get "/writing/tags/secret"

    expect(last_response).to be_not_found
  end

  describe "the sections" do
    describe "a tag on writing and on a project" do
      before do
        publish("hello", 1, tags: %w[ruby])
        create(:project, name: "sai", tags: %w[ruby])
        get "/writing/tags/ruby"
      end

      it "heads the writing and the projects separately" do
        expect(page.all("h2.tagged-title").map(&:text)).to eq(%w[Writing Projects])
      end

      it "lists the post and the project under their headings", :aggregate_failures do
        expect(page).to have_css(".entries .entry-title", text: "Hello")
        expect(page).to have_css(".projs .proj .n", exact_text: "sai")
      end
    end

    it "leaves the projects heading out when only writing carries the tag", :aggregate_failures do
      publish("hello", 1, tags: %w[ruby])
      get "/writing/tags/ruby"

      expect(page.all("h2.tagged-title").map(&:text)).to eq(%w[Writing])
      expect(page).to have_no_css(".projs")
    end

    it "leaves the writing heading out when only a project carries the tag", :aggregate_failures do
      create(:project, name: "sai", tags: %w[ruby])
      get "/writing/tags/ruby"

      expect(page.all("h2.tagged-title").map(&:text)).to eq(%w[Projects])
      expect(page).to have_no_css(".entries")
    end

    it "leaves the feed link out when no post carries the tag" do
      create(:project, name: "sai", tags: %w[ruby])
      get "/writing/tags/ruby"

      expect(page).to have_no_css("head link[rel='alternate']", visible: :all)
    end

    it "lists the projects the way the projects page does" do
      create(:project, name: "sai", tags: %w[ruby], stars: 21, release: "v1.0", tagline: "Terminal colors")
      get "/writing/tags/ruby"

      expect(page).to have_css(".proj .s", exact_text: "ruby · ★ 21 · v1.0")
    end
  end
end

# frozen_string_literal: true

RSpec.describe "Home", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:i18n) { Public::Slice["i18n"] }

  def feed_links
    page.all("head link[rel='alternate'][type='application/atom+xml']", visible: :all).map { [it[:href], it[:title]] }
  end

  def publish(slug, minutes_ago, **attrs)
    create(:post, :published, slug:, title: slug.capitalize, published_at: Time.now - (minutes_ago * 60), **attrs)
  end

  describe "the writing section" do
    it "lists the ten newest published posts, newest first" do
      12.times { |index| publish("post-#{index}", index + 1) }
      get "/"

      expect(page.all(".entry .entry-title").map(&:text)).to eq((0..9).map { "Post-#{it}" })
    end

    it "leaves out drafts and scheduled posts" do
      publish("shown", 1)
      %i[draft scheduled].each { create(:post, it) }
      get "/"

      expect(page.all(".entry .entry-title").map(&:text)).to eq(%w[Shown])
    end

    it "renders each row through the same list the writing index uses", :aggregate_failures do
      publish("hello", 1, tags: %w[ruby], summary: "What it is about")
      get "/"

      expect(page).to have_css(".entries.h-feed .entry-title a.entry-link[href='/writing/hello']", text: "Hello")
      expect(page).to have_css(".entry-blurb", exact_text: "What it is about")
    end

    it "names the section with a kicker and links to the writing page", :aggregate_failures do
      publish("hello", 1)
      get "/"

      expect(page).to have_css(".sec > .sec-h > .kicker:first-child", text: "Writing")
      expect(page).to have_css(".sec-h .sec-l[href='/writing']", text: "All writing")
    end

    it "says so when nothing is published", :aggregate_failures do
      get "/"

      expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.pages.index.no_writing"))
      expect(page).to have_no_css(".entries")
    end
  end

  describe "the projects section" do
    it "shows the three projects with the most stars, most first" do
      { "few" => 2, "most" => 30, "none" => 0, "some" => 9 }.each { |name, stars| create(:project, name:, stars:) }
      get "/"

      expect(page.all(".projs .proj .n").map(&:text)).to eq(%w[most some few])
    end

    it "leaves out an archived project with more stars" do
      create(:project, :archived, name: "gone", stars: 100)
      create(:project, name: "here", stars: 1)
      get "/"

      expect(page.all(".projs .proj .n").map(&:text)).to eq(%w[here])
    end

    it "leaves out archived projects" do
      create(:project, :archived, name: "gone")
      create(:project, name: "here")
      get "/"

      expect(page.all(".projs .proj .n").map(&:text)).to eq(%w[here])
    end

    it "leaves out private projects" do
      create(:project, :private, name: "hidden")
      create(:project, name: "here")
      get "/"

      expect(page.all(".projs .proj .n").map(&:text)).to eq(%w[here])
    end

    it "renders each card the way the projects page does" do
      create(:project, name: "sai", tags: %w[ruby], stars: 21, release: "v1.0", tagline: "Terminal colors")
      get "/"

      expect(page).to have_css(".proj .s", exact_text: "ruby · ★ 21 · v1.0")
    end

    it "names the section with a kicker and links to the projects page", :aggregate_failures do
      create(:project)
      get "/"

      expect(page).to have_css(".sec > .sec-h > .kicker:first-child", text: "Projects")
      expect(page).to have_css(".sec-h .sec-l[href='/projects']", text: "All projects")
    end

    it "says so when nothing is built", :aggregate_failures do
      get "/"

      expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.pages.index.no_projects"))
      expect(page).to have_no_css(".projs")
    end
  end

  it "names the page with a heading it never draws", :aggregate_failures do
    publish("hello", 1)
    create(:project)
    get "/"

    expect(page).to have_css("h1.sr-only", exact_text: i18n.t("ui.views.pages.index.heading"))
    expect(page.all("h1").length).to eq(1)
  end

  it "names its sections with a kicker rather than a heading" do
    publish("hello", 1)
    create(:project)
    get "/"

    expect(page).to have_no_css(".sec > h2, .sec-h h2")
  end

  it "titles the page with the site name" do
    get "/"

    expect(page).to have_title("Aaron Allen")
  end

  it "links the writing feed in the head" do
    get "/"

    expect(feed_links).to eq([["/writing.atom", "Writing | Aaron Allen"]])
  end
end

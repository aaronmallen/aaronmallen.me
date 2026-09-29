# frozen_string_literal: true

RSpec.describe "Writing", type: :request do
  let(:i18n) { Public::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }

  def feed_links
    page.all("head link[rel='alternate'][type='application/atom+xml']", visible: :all).map { [it[:href], it[:title]] }
  end

  def feedback_line = "#{show_copy('feedback.before')} #{show_copy('feedback.link')}#{show_copy('feedback.after')}"

  def index_copy(key) = i18n.t(key, scope: "ui.views.posts.index")

  def publish(slug, minutes_ago, **attrs)
    create(:post, :published, slug:, title: slug.capitalize, published_at: Time.now - (minutes_ago * 60), **attrs)
  end

  def show_copy(key) = i18n.t(key, scope: "ui.views.posts.show")

  describe "the index" do
    it "renders with no posts", :aggregate_failures do
      get "/writing"

      expect(last_response).to be_ok
      expect(page).to have_css(".writing .kicker", text: "Writing").and have_css(".writing-empty")
    end

    it "lists only published posts, newest first" do
      publish("older", 2)
      publish("newer", 1)
      %i[draft scheduled].each { create(:post, it) }
      get "/writing"

      expect(page.all(".entry .entry-title").map(&:text)).to eq(%w[Newer Older])
    end

    it "links each title to its article" do
      publish("hello", 1)
      get "/writing"

      expect(page).to have_css(".entry-title a.entry-link[href='/writing/hello']", text: "Hello")
    end

    it "uses the summary the post carries as the blurb" do
      publish("hello", 1, summary: "What it is about", body: "## Intro\n\nthe first part")
      get "/writing"

      expect(page).to have_css(".entry-blurb", exact_text: "What it is about")
    end

    it "falls back to the first paragraph when nobody wrote a summary" do
      publish("hello", 1, body: "## Intro\n\nthe first part\n\nthe second part")
      get "/writing"

      expect(page).to have_css(".entry-blurb", exact_text: "the first part")
    end

    it "leaves the blurb out when the body has no paragraph" do
      publish("hello", 1, body: "## Only a heading")
      get "/writing"

      expect(page).to have_css(".entry-title", text: "Hello").and have_no_css(".entry-blurb")
    end

    it "cuts a hand-written summary over the budget too" do
      publish("hello", 1, summary: "#{'a' * 119} bbbb", body: "the first part")
      get "/writing"

      expect(page).to have_css(".entry-blurb", exact_text: "#{'a' * 119}…")
    end

    it "cuts a first paragraph over the budget and ends it with an ellipsis" do
      publish("hello", 1, body: "#{'a' * 119} bbbb")
      get "/writing"

      expect(page).to have_css(".entry-blurb", exact_text: "#{'a' * 119}…")
    end

    it "keeps a family emoji whole where it cuts a first paragraph" do
      publish("hello", 1, body: "#{'a' * 119}👩‍👩‍👧‍👦 x")
      get "/writing"

      expect(page).to have_css(".entry-blurb", exact_text: "#{'a' * 119}👩‍👩‍👧‍👦…")
    end

    it "puts the date, tags and read time in the meta column" do
      body = "[#{'word ' * 440}](https://example.test/a/very/long/url)"
      create(:post, :published, tags: %w[ruby], body:, published_at: Time.utc(2026, 9, 7, 12))
      get "/writing"

      expect(page.find(".entry-meta").all("> *").map(&:text)).to eq(["Sep 7, 2026", "ruby", "2 min"])
    end

    it "links each tag to its tag page" do
      publish("hello", 1, tags: %w[ruby])
      get "/writing"

      expect(page).to have_css(".entry-meta a.post-tag[href='/writing/tags/ruby']", text: "ruby")
    end

    it "draws a tag in the colour the tag carries" do
      create(:tag, name: "ruby", color: "mk-violet")
      publish("hello", 1, tags: %w[ruby])
      get "/writing"

      expect(page).to have_css(".entry-meta a.post-tag.violet", text: "ruby")
    end

    it "titles the page" do
      get "/writing"

      expect(page).to have_title("Writing | Aaron Allen")
    end

    it "heads the page with a heading it never draws, over the kicker", :aggregate_failures do
      get "/writing"

      expect(page).to have_css(".writing > h1.sr-only:first-child", exact_text: index_copy("heading"))
      expect(page).to have_css(".writing > .kicker", exact_text: index_copy("kicker"))
      expect(page.all("h1").length).to eq(1)
    end

    it "points at no archive" do
      get "/writing"

      expect(page).to have_no_css(".writing p.eyebrow")
    end

    it "links the feed in the head once" do
      get "/writing"

      expect(feed_links).to eq([["/writing.atom", "Writing | Aaron Allen"]])
    end
  end

  describe "paging" do
    def titles = page.all(".entry .entry-title").map(&:text)

    before do
      lower_page_size(:public, to: 2)
      %w[first second third fourth fifth].each_with_index { |slug, index| publish(slug, 5 - index) }
    end

    it "shows the newest page and links to older posts", :aggregate_failures do
      get "/writing"

      expect(titles).to eq(%w[Fifth Fourth])
      expect(page).to have_css("nav.pager a[rel='next'][href='/writing?page=2']", text: "Older")
      expect(page).to have_no_css("nav.pager a[rel='prev']")
    end

    it "shows the next page and links both ways", :aggregate_failures do
      get "/writing?page=2"

      expect(titles).to eq(%w[Third Second])
      expect(page).to have_css("nav.pager a[rel='prev'][href='/writing']", text: "Newer")
      expect(page).to have_css("nav.pager a[rel='next'][href='/writing?page=3']", text: "Older")
    end

    it "links only to newer posts from the last page", :aggregate_failures do
      get "/writing?page=3"

      expect(titles).to eq(%w[First])
      expect(page).to have_css("nav.pager a[rel='prev'][href='/writing?page=2']")
      expect(page).to have_no_css("nav.pager a[rel='next']")
    end

    it "draws no pager when one page holds every post" do
      lower_page_size(:public, to: 5)
      get "/writing"

      expect(page).to have_no_css("nav.pager")
    end

    it "keeps the heading on a later page" do
      get "/writing?page=2"

      expect(page).to have_css(".writing > h1.sr-only", exact_text: index_copy("heading"))
    end

    it "names the page in the canonical link" do
      get "/writing?page=2"

      expect(page.find("link[rel='canonical']", visible: :all)[:href]).to eq("https://aaronmallen.me/writing?page=2")
    end

    it "returns 404 for a page past the end" do
      get "/writing?page=4"

      expect(last_response).to be_not_found
    end

    ["0", "-1", "1.5", "two", "", "2147483648"].each do |number|
      it "returns 404 for page #{number.inspect}, which is no page" do
        get "/writing?page=#{number}"

        expect(last_response).to be_not_found
      end
    end

    it "returns 404 for a page given as a list" do
      get "/writing?page[]=2"

      expect(last_response).to be_not_found
    end
  end

  describe "an article" do
    it "renders a published post", :aggregate_failures do
      publish("hello", 1, body: "the start\n\n## More\n\nthe rest")
      get "/writing/hello"

      expect(last_response).to be_ok
      expect(page).to have_css("article.post a.post-back[href='/writing'] + header h1.post-title", text: "Hello")
      expect(page).to have_css(".post-body > p:first-child", text: "the start").and have_css(".post-body h2")
    end

    it "closes the article with an eyebrow linking to contact", :aggregate_failures do
      publish("hello", 1)
      get "/writing/hello"

      expect(page).to have_css("article.post > p.eyebrow", exact_text: feedback_line)
      expect(page).to have_css("article.post > p.eyebrow a[href='/contact']", exact_text: show_copy("feedback.link"))
    end

    it "shows the date, tags and read time in the meta row" do
      create(:post, :published, slug: "hello", tags: %w[ruby hanami], published_at: Time.utc(2026, 9, 7, 12))
      get "/writing/hello"

      expect(page.find("header .post-meta"))
        .to have_css("time", text: "Sep 7, 2026").and have_css(".post-tag", count: 2).and have_text("1 min read")
    end

    it "links each tag to its tag page" do
      publish("hello", 1, tags: %w[ruby hanami])
      get "/writing/hello"

      expect(page.all("header .post-meta a.post-tag").map { it[:href] })
        .to eq(%w[/writing/tags/hanami /writing/tags/ruby])
    end

    it "links the writing feed in the head" do
      publish("hello", 1)
      get "/writing/hello"

      expect(feed_links).to eq([["/writing.atom", "Writing | Aaron Allen"]])
    end

    it "titles the page with the post" do
      publish("hello", 1)
      get "/writing/hello"

      expect(page).to have_title("Hello | Aaron Allen")
    end

    it "links back to writing from the footer" do
      publish("hello", 1)
      get "/writing/hello"

      expect(page).to have_css("article footer.post-footer a.post-footer-link[href='/writing']", text: "All writing")
    end

    it "links the previous and next posts in publish order", :aggregate_failures do
      %w[first second third].each_with_index { |slug, index| publish(slug, 3 - index) }
      get "/writing/second"

      expect(page).to have_css(".post-pager a[rel='prev'][href='/writing/first']", text: "First")
      expect(page).to have_css(".post-pager a[rel='next'][href='/writing/third']", text: "Third")
    end

    it "leaves out previous on the oldest post", :aggregate_failures do
      { "first" => 2, "second" => 1 }.each { publish(*it) }
      get "/writing/first"

      expect(page).to have_no_css("a[rel='prev']")
      expect(page).to have_css("a[rel='next'][href='/writing/second']")
    end

    it "leaves out next on the newest post", :aggregate_failures do
      { "first" => 2, "second" => 1 }.each { publish(*it) }
      get "/writing/second"

      expect(page).to have_no_css("a[rel='next']")
      expect(page).to have_css("a[rel='prev'][href='/writing/first']")
    end

    it "skips drafts and scheduled posts in the pager" do
      publish("only", 1)
      %i[draft scheduled].each { create(:post, it) }
      get "/writing/only"

      expect(page).to have_no_css(".post-pager a")
    end

    %i[draft scheduled].each do |status|
      it "returns 404 for a #{status} post" do
        create(:post, status, slug: "hidden")
        get "/writing/hidden"

        expect(last_response).to be_not_found
      end
    end

    it "returns 404 for a slug no post has" do
      get "/writing/nothing"

      expect(last_response).to be_not_found
    end

    it "returns 404 for a slug with capitals" do
      publish("hello", 1)
      get "/writing/Hello"

      expect(last_response).to be_not_found
    end

    %w[-hello hello- hello--world h%C3%A9llo hello_world].each do |slug|
      it "returns 404 for #{slug.inspect}, which is not in slug format" do
        get "/writing/#{slug}"

        expect(last_response).to be_not_found
      end
    end

    it "returns 404 for the reserved tags slug" do
      get "/writing/tags"

      expect(last_response).to be_not_found
    end

    it "serves the site's not found page for a slug no post has", :aggregate_failures do
      get "/writing/nothing"

      expect(last_response.content_type).to start_with("text/html")
      expect(last_response.body).to eq(Hanami.app.root.join("public/404.html").read)
    end
  end
end

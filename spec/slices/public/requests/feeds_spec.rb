# frozen_string_literal: true

RSpec.describe "Feeds", type: :request do
  let(:feed) { Nokogiri::XML(last_response.body).tap(&:remove_namespaces!) }

  def entry_ids = feed.xpath("/feed/entry/id").map(&:text)

  def post_urls(*slugs) = slugs.map { "https://aaronmallen.me/writing/#{it}" }

  def publish(slug, minutes_ago, **attrs)
    create(:post, :published, slug:, title: slug.capitalize, published_at: Time.now - (minutes_ago * 60), **attrs)
  end

  def publish_mixed(tag: "ruby")
    publish("older", 3, tags: [tag])
    publish("newer", 2, tags: ["hanami", tag])
    publish("other", 1, tags: %w[rust])
    %i[draft scheduled].each { create(:post, it, tags: [tag]) }
  end

  def value(xpath) = feed.at_xpath(xpath)&.text

  describe "/writing.atom" do
    it "serves valid Atom", :aggregate_failures do
      publish("hello", 1, tags: %w[ruby], body: "the <start> & more\n\n```ruby\nputs 1\n```")
      get "/writing.atom"

      expect(last_response.content_type).to eq("application/atom+xml; charset=utf-8")
      expect(last_response.body).to be_valid_atom
    end

    it "serves valid Atom with no posts" do
      get "/writing.atom"

      expect(last_response.body).to be_valid_atom
    end

    it "serves Atom to a reader that asks for it", :aggregate_failures do
      get "/writing.atom", {}, "HTTP_ACCEPT" => "application/atom+xml"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to eq("application/atom+xml; charset=utf-8")
    end

    it "serves Atom to a reader that takes anything" do
      get "/writing.atom", {}, "HTTP_ACCEPT" => "*/*"

      expect(last_response.content_type).to eq("application/atom+xml; charset=utf-8")
    end

    {
      "a browser" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "a reader that asks for RSS or XML" => "application/rss+xml, application/xml;q=0.9",
      "a reader that asks for text/xml" => "text/xml",
    }.each do |who, accept|
      it "serves Atom to #{who}", :aggregate_failures do
        get "/writing.atom", {}, "HTTP_ACCEPT" => accept

        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to eq("application/atom+xml; charset=utf-8")
      end
    end

    it "lists only published posts, newest first" do
      publish_mixed(tag: "anything")
      get "/writing.atom"

      expect(entry_ids).to eq(%w[https://aaronmallen.me/writing/other https://aaronmallen.me/writing/newer https://aaronmallen.me/writing/older])
    end

    it "names the feed, its page and its author" do
      get "/writing.atom"

      expect(%w[/feed/title /feed/id /feed/author/name].map { value(it) })
        .to eq(["Writing | Aaron Allen", "https://aaronmallen.me/writing", "Aaron Allen"])
    end

    it "links the page and the feed itself" do
      get "/writing.atom"

      expect(%w[alternate self].map { feed.at_xpath("/feed/link[@rel='#{it}']")[:href] })
        .to eq(%w[https://aaronmallen.me/writing https://aaronmallen.me/writing.atom])
    end

    it "sets the feed's updated time to the latest post change" do
      create(:post, :published, published_at: Time.utc(2026, 9, 1), updated_at: Time.utc(2026, 9, 9))
      create(:post, :published, published_at: Time.utc(2026, 9, 5), updated_at: Time.utc(2026, 9, 5))
      get "/writing.atom"

      expect(value("/feed/updated")).to eq("2026-09-09T00:00:00Z")
    end
  end

  describe "an entry" do
    let(:entry) { feed.at_xpath("/feed/entry") }

    before do
      published_at = Time.utc(2026, 9, 7, 12)
      create(:post, :published, slug: "hello", title: "Hello", tags: %w[ruby hanami], published_at:,
                                updated_at: published_at + 60, body: "the *start*\n\nthe rest")
      get "/writing.atom"
    end

    it "has the title and a link to the article" do
      expect([entry.at_xpath("title").text, entry.at_xpath("link[@rel='alternate']")[:href]])
        .to eq(["Hello", "https://aaronmallen.me/writing/hello"])
    end

    it "has the publish and update times" do
      expect(%w[published updated].map { entry.at_xpath(it).text }).to eq(%w[2026-09-07T12:00:00Z 2026-09-07T12:01:00Z])
    end

    it "has a category per tag" do
      expect(entry.xpath("category").map { it[:term] }).to eq(%w[hanami ruby])
    end

    it "has the first paragraph as the summary" do
      expect(entry.at_xpath("summary").text).to eq("the start")
    end

    it "has the rendered body as HTML content" do
      expect(Capybara.string(entry.at_xpath("content[@type='html']").text)).to have_css("p em", text: "start")
    end
  end

  it "has the summary the post carries" do
    publish("hello", 1, summary: "What it is about", body: "the start")
    get "/writing.atom"

    expect(feed.at_xpath("/feed/entry/summary").text).to eq("What it is about")
  end

  it "escapes markup in titles and bodies" do
    publish("hello", 1, title: "<b>bold</b> & more", body: "a <script>alert(1)</script> & b")
    get "/writing.atom"

    expect(%w[title content].map { feed.at_xpath("/feed/entry/#{it}").text })
      .to eq(["<b>bold</b> & more", Posts::Markdown.to_html("a <script>alert(1)</script> & b")])
  end

  it "leaves out the summary when the body has no paragraph" do
    publish("hello", 1, body: "## Only a heading")
    get "/writing.atom"

    expect(feed.at_xpath("/feed/entry/summary")).to be_nil
  end

  describe "a tag feed" do
    it "serves valid Atom", :aggregate_failures do
      publish("hello", 1, tags: %w[ruby])
      get "/writing/tags/ruby.atom"

      expect(last_response.content_type).to eq("application/atom+xml; charset=utf-8")
      expect(last_response.body).to be_valid_atom
    end

    it "serves Atom to a reader that asks for it", :aggregate_failures do
      publish("hello", 1, tags: %w[ruby])
      get "/writing/tags/ruby.atom", {}, "HTTP_ACCEPT" => "application/atom+xml"

      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to eq("application/atom+xml; charset=utf-8")
    end

    it "serves Atom to a browser" do
      publish("hello", 1, tags: %w[ruby])
      get "/writing/tags/ruby.atom", {},
          "HTTP_ACCEPT" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

      expect(last_response.status).to eq(200)
    end

    it "lists only published posts with the tag, newest first" do
      publish_mixed
      get "/writing/tags/ruby.atom"

      expect(entry_ids).to eq(%w[https://aaronmallen.me/writing/newer https://aaronmallen.me/writing/older])
    end

    it "names the feed and its page" do
      publish("hello", 1, tags: %w[ruby])
      get "/writing/tags/ruby.atom"

      expect(%w[/feed/title /feed/id].map { value(it) })
        .to eq(["Writing tagged ruby | Aaron Allen", "https://aaronmallen.me/writing/tags/ruby"])
    end

    it "links the feed itself" do
      publish("hello", 1, tags: %w[ruby])
      get "/writing/tags/ruby.atom"

      expect(feed.at_xpath("/feed/link[@rel='self']")[:href]).to eq("https://aaronmallen.me/writing/tags/ruby.atom")
    end

    it "finds a tag with a dash in it" do
      publish("hello", 1, tags: %w[open-source])
      get "/writing/tags/open-source.atom"

      expect(entry_ids).to eq(%w[https://aaronmallen.me/writing/hello])
    end

    it "finds the tag whatever case the url uses" do
      publish("hello", 1, tags: %w[ruby])
      get "/writing/tags/RUBY.atom"

      expect(entry_ids).to eq(%w[https://aaronmallen.me/writing/hello])
    end

    it "returns 404 for a url that is no tag" do
      publish("hello", 1, tags: %w[ruby])
      get "/writing/tags/open%20source.atom"

      expect(last_response).to be_not_found
    end

    it "returns 404 for a tag no published post has" do
      create(:post, :draft, tags: %w[secret])
      get "/writing/tags/secret.atom"

      expect(last_response).to be_not_found
    end
  end

  it "carries the newest 25 posts" do
    26.times { publish("post-#{it}", it) }
    get "/writing.atom"

    expect(entry_ids).to eq(Array.new(25) { "https://aaronmallen.me/writing/post-#{it}" })
  end

  describe "paging" do
    def link(rel) = feed.at_xpath("/feed/link[@rel='#{rel}']")&.[](:href)

    def links = %w[self alternate next previous].to_h { [it, link(it)] }

    before do
      lower_page_size(:public, to: 2)
      %w[first second third fourth fifth].each_with_index { |slug, index| publish(slug, 5 - index, tags: %w[ruby]) }
    end

    {
      "/writing.atom" => ["https://aaronmallen.me/writing", "https://aaronmallen.me/writing.atom"],
      "/writing/tags/ruby.atom" => ["https://aaronmallen.me/writing/tags/ruby",
                                    "https://aaronmallen.me/writing/tags/ruby.atom"],
    }.each do |path, (html, atom)|
      describe path do
        it "carries the newest page and links to older posts", :aggregate_failures do
          get path

          expect(entry_ids).to eq(post_urls("fifth", "fourth"))
          expect(links).to eq("self" => atom, "alternate" => html, "next" => "#{atom}?page=2", "previous" => nil)
        end

        it "names the next page and links both ways", :aggregate_failures do
          get "#{path}?page=2"

          expect(entry_ids).to eq(post_urls("third", "second"))
          expect(links).to eq("self" => "#{atom}?page=2", "alternate" => "#{html}?page=2",
                              "next" => "#{atom}?page=3", "previous" => atom)
        end

        it "links only to newer posts from the last page", :aggregate_failures do
          get "#{path}?page=3"

          expect(entry_ids).to eq(%w[https://aaronmallen.me/writing/first])
          expect(links).to eq("self" => "#{atom}?page=3", "alternate" => "#{html}?page=3",
                              "next" => nil, "previous" => "#{atom}?page=2")
        end

        it "keeps one feed id on every page" do
          get "#{path}?page=2"

          expect(value("/feed/id")).to eq(html)
        end

        it "serves valid Atom on a later page" do
          get "#{path}?page=2"

          expect(last_response.body).to be_valid_atom
        end

        it "links no other page when one page holds every post" do
          lower_page_size(:public, to: 5)
          get path

          expect(links.values_at("next", "previous")).to eq([nil, nil])
        end

        it "returns 404 for a page past the end" do
          get "#{path}?page=4"

          expect(last_response).to be_not_found
        end

        it "returns 404 for a page that is no page" do
          get "#{path}?page=two"

          expect(last_response).to be_not_found
        end
      end
    end
  end

  describe "a reader polling again" do
    let(:post_repo) { Posts::Slice["repos.post_repo"] }
    let(:yesterday) { Time.now - (24 * 60 * 60) }

    def poll(path, etag: nil, last_modified: nil)
      headers = { "HTTP_IF_NONE_MATCH" => etag, "HTTP_IF_MODIFIED_SINCE" => last_modified }.compact
      get path, {}, headers
    end

    def validators = { etag: last_response.headers["ETag"], last_modified: last_response.headers["Last-Modified"] }

    def watch_markdown = allow(Posts::Markdown).to receive(:to_html).and_call_original

    before do
      create(:post, :published, slug: "older", tags: %w[ruby], published_at: yesterday - 60, updated_at: yesterday - 60)
      create(:post, :published, slug: "hello", tags: %w[ruby], published_at: yesterday, updated_at: yesterday)
    end

    it "names the newest post change as the time the feed last changed" do
      get "/writing.atom"

      expect(last_response.headers["Last-Modified"]).to eq(yesterday.httpdate)
    end

    it "tags the feed with a weak ETag" do
      get "/writing.atom"

      expect(last_response.headers["ETag"]).to match(%r{\AW/"\h{64}"\z})
    end

    %w[/writing.atom /writing/tags/ruby.atom].each do |path|
      describe path do
        before { get path }

        it "answers 304 with no body to a reader that sends the time back", :aggregate_failures do
          poll(path, last_modified: validators[:last_modified])

          expect(last_response.status).to eq(304)
          expect(last_response.body).to be_empty
        end

        it "answers 304 with no body to a reader that sends the ETag back", :aggregate_failures do
          poll(path, etag: validators[:etag])

          expect(last_response.status).to eq(304)
          expect(last_response.body).to be_empty
        end

        it "repeats the ETag and the Vary on a 304" do
          sent = validators
          poll(path, **sent)

          expect(last_response.headers.to_h.slice("etag", "vary")).to eq("etag" => sent[:etag], "vary" => "Cookie")
        end

        it "renders no Markdown for a 304" do
          watch_markdown
          poll(path, **validators)

          expect(Posts::Markdown).not_to have_received(:to_html)
        end

        it "answers 200 with the new entry once another post is published", :aggregate_failures do
          sent = validators
          publish("newest", 0, tags: %w[ruby])
          poll(path, **sent)

          expect(last_response.status).to eq(200)
          expect(entry_ids.first).to eq("https://aaronmallen.me/writing/newest")
        end

        it "answers 200 with the edit once a post changes", :aggregate_failures do
          sent = validators
          post_repo.update(post_repo.published_by_slug("older").id, title: "Revised")
          poll(path, **sent)

          expect(last_response.status).to eq(200)
          expect(feed.xpath("/feed/entry/title").map(&:text)).to include("Revised")
        end

        it "answers 200 without a deleted entry though the newest change stands", :aggregate_failures do
          sent = validators
          post_repo.delete(post_repo.published_by_slug("older").id)
          poll(path, **sent)

          expect(last_response.status).to eq(200)
          expect(entry_ids).to eq(%w[https://aaronmallen.me/writing/hello])
        end
      end
    end

    %w[/writing.atom?page=2 /writing/tags/ruby.atom?page=2].each do |path|
      describe "#{path} at one post a page" do
        before do
          lower_page_size(:public, to: 1)
          get path
        end

        it "answers 304 to a reader that sends the time back" do
          poll(path, last_modified: validators[:last_modified])

          expect(last_response.status).to eq(304)
        end

        it "answers 304 to a reader that sends the ETag back" do
          poll(path, etag: validators[:etag])

          expect(last_response.status).to eq(304)
        end

        it "answers 200 once a newer post pushes another onto the page", :aggregate_failures do
          sent = validators
          publish("newest", 0, tags: %w[ruby])
          poll(path, **sent)

          expect(last_response.status).to eq(200)
          expect(entry_ids).to eq(%w[https://aaronmallen.me/writing/hello])
        end
      end
    end

    describe "the last page at one post a page" do
      before do
        lower_page_size(:public, to: 1)
        get "/writing.atom?page=2"
      end

      it "answers 200 once an older page appears" do
        sent = validators
        publish("oldest", 3 * 24 * 60)
        poll("/writing.atom?page=2", etag: sent[:etag])

        expect(last_response.status).to eq(200)
      end
    end
  end

  describe "a request arriving on another host" do
    let(:elsewhere) { { "HTTP_HOST" => "pi.local" } }

    before { publish("hello", 1, tags: %w[ruby]) }

    def canonical(path)
      get path, {}, elsewhere

      Capybara.string(last_response.body).find("link[rel='canonical']", visible: :all)[:href]
    end

    it "names the site setting in the entry ids" do
      get "/writing.atom", {}, elsewhere

      expect(entry_ids).to eq(%w[https://aaronmallen.me/writing/hello])
    end

    it "names the site setting in the feed's own links" do
      get "/writing.atom", {}, elsewhere

      expect(%w[alternate self].map { feed.at_xpath("/feed/link[@rel='#{it}']")[:href] })
        .to eq(%w[https://aaronmallen.me/writing https://aaronmallen.me/writing.atom])
    end

    it "names the site setting in a tag feed" do
      get "/writing/tags/ruby.atom", {}, elsewhere

      expect(feed.at_xpath("/feed/link[@rel='self']")[:href]).to eq("https://aaronmallen.me/writing/tags/ruby.atom")
    end

    it "gives the entry id the canonical link already gives" do
      get "/writing.atom", {}, elsewhere
      ids = entry_ids

      expect(ids).to eq([canonical("/writing/hello")])
    end
  end
end

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

  def watch_markdown = %i[parse to_html].each { allow(Commonmarker).to receive(it).and_call_original }

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

    it "has the title and a link to the article tagged as from the feed" do
      expect([entry.at_xpath("title").text, entry.at_xpath("link[@rel='alternate']")[:href]])
        .to eq(["Hello", "https://aaronmallen.me/writing/hello?ref=feed"])
    end

    it "keeps the untagged article url as its id" do
      expect(entry.at_xpath("id").text).to eq("https://aaronmallen.me/writing/hello")
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

    it "gives the body's headings the ids the article does" do
      create(:post, :published, slug: "headed", body: "## The Setup")
      get "/writing.atom"

      content = feed.at_xpath("/feed/entry[id='https://aaronmallen.me/writing/headed']/content").text

      expect(Capybara.string(content)).to have_css("h2#the-setup")
    end
  end

  describe "an entry for a post with notes" do
    let(:post_record) { create(:post, :published, slug: "hello", body: "the start") }

    def content = Capybara.string(feed.at_xpath("/feed/entry/content").text)

    def edit(note, at:) = create(:post_edit, post: post_record, note:, created_at: at, updated_at: at)

    it "ends with the notes after the body", :aggregate_failures do
      edit("fixed the numbers", at: Time.utc(2026, 9, 7, 12))
      get "/writing.atom"

      expect(content.all("body > *").map(&:tag_name)).to eq(%w[p section])
      expect(content.find(".post-edit").text(normalize_ws: true)).to eq("Edited Sep 7, 2026 fixed the numbers")
    end

    it "dates a note by the site's day, not UTC's" do
      edit("late night fix", at: Time.utc(2026, 9, 8, 3))
      get "/writing.atom"

      expect(content.find(".post-edit-date")).to have_text("Edited Sep 7, 2026")
    end

    describe "notes from two days" do
      before do
        edit("fixed the numbers", at: Time.utc(2026, 9, 7, 12))
        edit("fixed a link", at: Time.utc(2026, 9, 7, 15))
        edit("fixed a typo", at: Time.utc(2026, 9, 9, 12))
        get "/writing.atom"
      end

      it "shows each date once, newest first" do
        expect(content.all(".post-edit-date").map(&:text)).to eq(["Edited Sep 9, 2026", "Edited Sep 7, 2026"])
      end

      it "lists one day's notes under its date, oldest first" do
        expect(content.all(".post-edit-item").map { it.text.strip }).to eq(["fixed the numbers", "fixed a link"])
      end

      it "shows a day's single note on its own" do
        expect(content.find(".post-edit-note").text.strip).to eq("fixed a typo")
      end
    end

    it "renders the note's Markdown", :aggregate_failures do
      edit("fixed `count` and [the link](https://example.com/docs)", at: Time.utc(2026, 9, 7, 12))
      get "/writing.atom"

      expect(content).to have_css(".post-edit-note code", text: "count")
      expect(content).to have_link("the link", href: "https://example.com/docs")
    end

    it "escapes raw HTML in a note" do
      edit("fixed <script>alert(1)</script> it", at: Time.utc(2026, 9, 7, 12))
      get "/writing.atom"

      expect(content).to have_no_css(".post-edit-note script")
    end

    it "serves valid Atom" do
      edit("fixed the numbers", at: Time.utc(2026, 9, 7, 12))
      get "/writing.atom"

      expect(last_response.body).to be_valid_atom
    end

    it "leaves the notes off another post's entry" do
      edit("fixed the numbers", at: Time.utc(2026, 9, 7, 12))
      publish("other", 0, body: "the other")
      get "/writing.atom"

      other = feed.at_xpath("/feed/entry[id='https://aaronmallen.me/writing/other']/content")

      expect(other.text).to eq(Posts::Markdown.to_html("the other"))
    end

    it "loads the notes for the whole page in one query" do
      edit("fixed the numbers", at: Time.utc(2026, 9, 7, 12))
      2.times { |n| create(:post_edit, post: publish("other#{n}", n), note: "fixed #{n}") }

      notes = counting { get "/writing.atom" }.grep(/FROM "post_edits"/).grep_v(/GROUP BY/)

      expect(notes).to have(1).item
    end

    it "issues the same statements for three posts with notes as for one" do
      edit("fixed the numbers", at: Time.utc(2026, 9, 7, 12))
      one = counting { get "/writing.atom" }.size
      2.times { |n| create(:post_edit, post: publish("other#{n}", n), note: "fixed #{n}") }

      expect(counting { get "/writing.atom" }).to have(one).items
    end
  end

  it "keeps the body alone as the content of a post with no notes" do
    publish("hello", 1, body: "the *start*")
    get "/writing.atom"

    expect(feed.at_xpath("/feed/entry/content").text).to eq(Posts::Markdown.to_html("the *start*"))
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

    it "moves a url that spells the tag in another case to the tag's own feed", :aggregate_failures do
      publish("hello", 1, tags: %w[ruby])
      get "/writing/tags/RUBY.atom"

      expect(last_response.status).to eq(301)
      expect(last_response.location).to eq("/writing/tags/ruby.atom")
    end

    it "keeps the page when it moves a url to the tag's own feed" do
      publish("hello", 1, tags: %w[ruby])
      get "/writing/tags/Ruby.atom?page=2"

      expect(last_response.location).to eq("/writing/tags/ruby.atom?page=2")
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
    def older_entry(field) = feed.at_xpath("/feed/entry[id='https://aaronmallen.me/writing/older']/#{field}").text

    def poll(path, etag: nil, last_modified: nil)
      headers = { "HTTP_IF_NONE_MATCH" => etag, "HTTP_IF_MODIFIED_SINCE" => last_modified }.compact
      get path, {}, headers
    end
    let(:yesterday) { Time.now - (24 * 60 * 60) }
    let(:note) { create(:post_edit, post: older, note: "fixed a typo", created_at: yesterday, updated_at: yesterday) }
    let(:older) { post_queries.published_by_slug("older") }

    def post_mutations = Posts::Slice["repos.post_mutations"]

    def post_queries = Posts::Slice["repos.post_queries"]

    def remove_tag(name)
      tag = Tags::Slice["repos.tag_queries"].all_in("public").find { it.name == name }
      Tags::Slice["repos.tag_mutations"].delete(tag.id)
    end

    def rename_tag(from, to)
      tag = Tags::Slice["repos.tag_queries"].all_in("public").find { it.name == from }
      Tags::Slice["repos.tag_mutations"].update(tag.id, name: to)
    end

    def retag(slug, names) = post_mutations.replace_tags(post_queries.published_by_slug(slug).id, names)

    def revise_note = Posts::Slice["repos.post_edit_mutations"].update(note.id, note: "fixed two typos")

    before do
      create(:post, :published, slug: "older", tags: %w[ruby], published_at: yesterday - 60, updated_at: yesterday - 60)
      create(:post, :published, slug: "hello", tags: %w[hanami ruby], published_at: yesterday, updated_at: yesterday)
    end

    def validators = { etag: last_response.headers["ETag"], last_modified: last_response.headers["Last-Modified"] }

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

        it "renders no Markdown for a 304", :aggregate_failures do
          watch_markdown
          poll(path, **validators)

          expect(Commonmarker).not_to have_received(:parse)
          expect(Commonmarker).not_to have_received(:to_html)
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
          post_mutations.update(post_queries.published_by_slug("older").id, title: "Revised")
          poll(path, **sent)

          expect(last_response.status).to eq(200)
          expect(feed.xpath("/feed/entry/title").map(&:text)).to include("Revised")
        end

        it "answers 200 without a deleted entry though the newest change stands", :aggregate_failures do
          sent = validators
          post_mutations.delete(post_queries.published_by_slug("older").id)
          poll(path, **sent)

          expect(last_response.status).to eq(200)
          expect(entry_ids).to eq(%w[https://aaronmallen.me/writing/hello])
        end

        it "answers 200 without a deleted entry to a reader that sends only the time back", :aggregate_failures do
          sent = validators
          post_mutations.delete(older.id)
          poll(path, last_modified: sent[:last_modified])

          expect(last_response.status).to eq(200)
          expect(entry_ids).to eq(%w[https://aaronmallen.me/writing/hello])
        end

        it "answers 200 with the new category once a tag on the page is renamed", :aggregate_failures do
          sent = validators
          rename_tag("hanami", "rails")
          poll(path, etag: sent[:etag])

          expect(last_response.status).to eq(200)
          expect(feed.xpath("/feed/entry/category").map { it[:term] }).to include("rails")
        end

        it "answers 200 with the new category to a reader that sends only the time back", :aggregate_failures do
          sent = validators
          rename_tag("hanami", "rails")
          poll(path, last_modified: sent[:last_modified])

          expect(last_response.status).to eq(200)
          expect(feed.xpath("/feed/entry/category").map { it[:term] }).to include("rails")
        end

        it "answers 200 to a reader with only the time once the newest post loses a tag", :aggregate_failures do
          sent = validators
          retag("hello", %w[hanami])
          poll(path, last_modified: sent[:last_modified])

          expect(last_response.status).to eq(200)
          expect(feed.xpath("/feed/entry[category/@term='ruby']/id").map(&:text)).to eq(post_urls("older"))
        end

        it "answers 200 without a tag to a reader with only the time once it is deleted", :aggregate_failures do
          sent = validators
          remove_tag("hanami")
          poll(path, last_modified: sent[:last_modified])

          expect(last_response.status).to eq(200)
          expect(feed.xpath("/feed/entry/category").map { it[:term] }).not_to include("hanami")
        end

        it "answers 304 to a reader that sends only the time back after a post keeps its tags" do
          sent = validators
          retag("hello", %w[hanami ruby])
          poll(path, last_modified: sent[:last_modified])

          expect(last_response.status).to eq(304)
        end

        it "answers 304 to a reader that sends only the time back after a draft loses a tag" do
          sent = validators
          draft = create(:post, :draft, tags: %w[ruby secret])
          post_mutations.replace_tags(draft.id, %w[secret])
          poll(path, last_modified: sent[:last_modified])

          expect(last_response.status).to eq(304)
        end

        it "answers 304 to a reader that sends only the time back after a tag off the page is renamed" do
          sent = validators
          create(:post, :draft, tags: %w[secret])
          rename_tag("secret", "hidden")
          poll(path, last_modified: sent[:last_modified])

          expect(last_response.status).to eq(304)
        end
      end

      describe "#{path} with an edit note" do
        before do
          note
          get path
        end

        it "answers 304 while nothing changes", :aggregate_failures do
          sent = validators
          poll(path, etag: sent[:etag])
          by_etag = last_response.status
          poll(path, last_modified: sent[:last_modified])

          expect([by_etag, last_response.status]).to eq([304, 304])
        end

        it "changes the ETag and the time once the note is revised", :aggregate_failures do
          sent = validators
          revise_note
          get path

          expect(validators[:etag]).not_to eq(sent[:etag])
          expect(Time.httpdate(validators[:last_modified])).to be > Time.httpdate(sent[:last_modified])
        end

        it "answers 200 with the revised note to a reader that sends the ETag back", :aggregate_failures do
          sent = validators
          revise_note
          poll(path, etag: sent[:etag])

          expect(last_response.status).to eq(200)
          expect(older_entry("content")).to include("fixed two typos")
        end

        it "answers 200 with the revised note to a reader that sends only the time back", :aggregate_failures do
          sent = validators
          revise_note
          poll(path, last_modified: sent[:last_modified])

          expect(last_response.status).to eq(200)
          expect(older_entry("content")).to include("fixed two typos")
        end

        it "moves the entry's updated time to the revised note" do
          revise_note
          get path

          expect(Time.iso8601(older_entry("updated"))).to be > yesterday
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

  describe "a reader sending back a time in another shape" do
    let(:changed_at) { Time.utc(2026, 10, 1, 12) }

    def poll(path, last_modified) = get path, {}, "HTTP_IF_MODIFIED_SINCE" => last_modified

    before do
      create(:post, :published, slug: "hello", tags: %w[ruby], published_at: changed_at, updated_at: changed_at)
    end

    %w[/writing.atom /writing/tags/ruby.atom].each do |path|
      describe path do
        it "answers 304 to a time with a one-digit day", :aggregate_failures do
          poll(path, "Thu, 1 Oct 2026 12:00:00 GMT")

          expect(last_response.status).to eq(304)
          expect(last_response.body).to be_empty
        end

        it "answers 200 to a time with a one-digit day from before the change" do
          poll(path, "Thu, 1 Oct 2026 11:59:59 GMT")

          expect(last_response.status).to eq(200)
        end

        it "answers 304 to a time in the obsolete RFC 850 shape" do
          poll(path, "Thursday, 01-Oct-26 12:00:00 GMT")

          expect(last_response.status).to eq(304)
        end

        it "answers 200 with the feed to a time that is no date", :aggregate_failures do
          poll(path, "not a date")

          expect(last_response.status).to eq(200)
          expect(last_response.body).to be_valid_atom
        end
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

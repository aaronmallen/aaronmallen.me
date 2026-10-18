# frozen_string_literal: true

RSpec.describe "Search", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def groups = page.all(".sq-g").map { it.find("h2").text }

  def kind_links = page.all(".sq-k a").map { [it.text, it[:href]] }

  def publish(title, minutes_ago: 1, **)
    slug = title.downcase.tr(" ", "-")
    create(:post, :published, title:, slug:, published_at: Time.now - (minutes_ago * 60), **)
  end

  it "shows the search link in the header of every public page", :aggregate_failures do
    %w[/ /writing /about /projects /contact].each do |path|
      get path

      expect(page).to have_css("header a.search-link[href='/search'][aria-label='Search']", text: "search")
    end
  end

  it "marks the search link current on the search page" do
    get "/search"

    expect(page).to have_css("a.search-link[aria-current='page']")
  end

  it "keeps the page out of search engines and lets caches keep it", :aggregate_failures do
    get "/search", q: "zeppelin"

    expect(page).to have_css("meta[name='robots'][content='noindex']", visible: :all)
    expect(last_response.headers["Cache-Control"]).to include("s-maxage=300")
  end

  it "has an h1" do
    get "/search"

    expect(page).to have_css("h1", text: "Search", visible: :all)
  end

  describe "with matches in every kind" do
    let(:board) { create(:project, name: "Board", tagline: "Plans", board_published: true) }

    before do
      4.times { publish("Zeppelin #{it}", minutes_ago: it + 1) }
      create(:project, name: "Zeppelin", tagline: "A zeppelin tool")
      create(:task, title: "Fly the zeppelin", project_id: board.id)
    end

    it "shows the total and the count of each kind" do
      get "/search", q: "zeppelin"

      expect(page.find(".sq-c")).to have_text("6 results for “zeppelin”: 4 posts, 1 project, 1 task")
    end

    it "links each kind with its count" do
      get "/search", q: "zeppelin"

      expect(kind_links).to eq(
        [["all 6", ""], ["posts 4", "&kind=post"], ["projects 1", "&kind=project"], ["tasks 1", "&kind=task"]]
          .map { |text, kind| [text, "/search?q=zeppelin#{kind}"] },
      )
    end

    it "groups three rows of each kind and links to the rest", :aggregate_failures do
      get "/search", q: "zeppelin"

      expect(groups).to eq(["Posts · 4", "Projects · 1", "Tasks · 1"])
      expect(page.first(".sq-g").all("li.entry").length).to eq(3)
      expect(page).to have_link("All 4 posts matching “zeppelin”", href: "/search?q=zeppelin&kind=post")
      expect(page).to have_no_link(href: "/search?q=zeppelin&kind=project", text: "All")
    end

    it "shows one kind when asked, with counts that match", :aggregate_failures do
      get "/search", q: "zeppelin", kind: "post"

      expect(groups).to eq(["Posts · 4"])
      expect(page.all("li.entry").length).to eq(4)
      expect(page).to have_css(".sq-k a[aria-current='page']", text: "posts 4")
      expect(page).to have_no_css(".sq-more")
    end

    it "pages through one kind" do
      get "/search", q: "zeppelin", kind: "post", page: 9

      expect(last_response.status).to eq(404)
    end

    it "shows each kind's label with its date, status or number", :aggregate_failures do
      get "/search", q: "zeppelin"

      expect(page.first(".entry-meta").text).to match(/\Apost\w{3} \d+, \d{4}\z/)
      expect(page).to have_css(".entry-meta", exact_text: "projectactive")
      expect(page).to have_css(".entry-meta", text: /\Atask#\d+\z/)
    end

    it "links each hit to its page", :aggregate_failures do
      get "/search", q: "zeppelin"

      expect(page).to have_link("Zeppelin 3", href: "/writing/zeppelin-3")
      expect(page).to have_link("Zeppelin", href: "/projects", exact: true)
      expect(page).to have_link("Fly the zeppelin", href: %r{\A/projects/board/tasks/\d+\z})
    end

    it "shows a task's status and board" do
      get "/search", q: "zeppelin"

      expect(page.find(".sq-t").text).to eq("openBoard board")
    end
  end

  it "links a project with a published board to its board" do
    create(:project, name: "Zeppelin", tagline: "A zeppelin tool", board_published: true)
    get "/search", q: "zeppelin"

    expect(page).to have_link("Zeppelin", href: "/projects/zeppelin")
  end

  it "marks the matches and escapes the record's own HTML", :aggregate_failures do
    publish("Airships", body: "A zeppelin & a blimp, 1 < 2 > 0, <mark>no</mark>")
    get "/search", q: "zeppelin"

    blurb = page.find(".entry-blurb")
    expect(blurb.all("mark").map(&:text)).to eq(["zeppelin"])
    expect(last_response.body).to include("<mark>zeppelin</mark> &amp; a blimp, 1 &lt; 2 &gt; 0")
  end

  describe "the ways forward" do
    before do
      create(:tag, name: "ruby", color: "mk-violet")
      publish("First", minutes_ago: 4, tags: %w[ruby rust])
      publish("Second", minutes_ago: 3, tags: %w[ruby])
      publish("Third", minutes_ago: 2)
      publish("Fourth", minutes_ago: 1)
      create(:post, :draft, title: "Draft", tags: %w[draft-only])
    end

    def chips = page.all(".tgc a").map { [it.text, it[:href]] }

    def latest = page.all(".rcl a").map(&:text)

    it "shows tag chips with counts and the latest posts on a blank search", :aggregate_failures do
      get "/search"

      expect(chips).to eq([["ruby 2", "/writing/tags/ruby"], ["rust 1", "/writing/tags/rust"]])
      expect(page).to have_css(".tgc a.violet", text: "ruby")
      expect(latest).to eq(%w[Fourth Third Second])
      expect(page).to have_no_css("#results")
    end

    it "shows them with the no results state", :aggregate_failures do
      get "/search", q: "kafka streams"

      expect(page).to have_css(".sq-n h2", text: "Nothing matched “kafka streams”")
      expect(page).to have_field("q", with: "kafka streams")
      expect(chips.map(&:first)).to eq(["ruby 2", "rust 1"])
      expect(latest).to eq(%w[Fourth Third Second])
    end

    it "leaves them off when a search finds something" do
      get "/search", q: "fourth"

      expect(page).to have_no_css(".sq-w")
    end
  end

  describe "when the search fails" do
    let(:agent) { Hanami.app["honeybadger.agent"] }

    before do
      allow(agent).to receive(:notify)
      queries = Search::Slice["repos.public_search_queries"]
      allow(queries).to receive(:counts).and_raise(Sequel::DatabaseError)
      replace_component("search.repos.public_search_queries", queries)
      get "/search", q: "zeppelin"
    end

    it "shows the error state", :aggregate_failures do
      expect(last_response.status).to eq(503)
      expect(page).to have_css(".sq-n.err h2", text: "Search isn’t working right now")
      expect(page).to have_no_css(".sq-w")
    end

    it "offers to try again" do
      expect(page).to have_link("Try again", href: "/search?q=zeppelin")
    end

    it "tells Honeybadger" do
      expect(agent).to have_received(:notify).with(Sequel::DatabaseError)
    end
  end

  it "ignores a kind it does not know" do
    publish("Zeppelin")
    get "/search", q: "zeppelin", kind: "journal_entry"

    expect(groups).to eq(["Posts · 1"])
  end

  describe "the throttle" do
    def attempts = Search::Slice["relations.search_attempts"].count

    def search(address = "203.0.113.9", **) = get("/search", { q: "zeppelin", ** }, { "REMOTE_ADDR" => address })

    before do
      publish("Zeppelin")
      lower_throttle_limit(:search, to: 2)
    end

    it "records an attempt for each search" do
      expect { 2.times { search } }.to change { attempts }.by(2)
    end

    describe "when it cannot count the search" do
      let(:agent) { Hanami.app["honeybadger.agent"] }

      before do
        allow(agent).to receive(:notify)
        claim = Search::Slice["operations.claim_search_attempt"]
        allow(claim).to receive(:call).and_raise(Sequel::DatabaseError)
        replace_component("search.operations.claim_search_attempt", claim)
        search
      end

      it "still searches" do
        expect(groups).to eq(["Posts · 1"])
      end

      it "tells Honeybadger" do
        expect(agent).to have_received(:notify).with(Sequel::DatabaseError)
      end
    end

    it "locks both of the searcher's addresses in one statement" do
      expect(counting(/pg_advisory_xact_lock/) { search }.map { it.scan("pg_advisory_xact_lock").size }).to eq([2])
    end

    it "records nothing for the blank page" do
      expect { get "/search" }.not_to(change { attempts })
    end

    it "searches as before under the limit", :aggregate_failures do
      2.times { search }

      expect(last_response.status).to eq(200)
      expect(groups).to eq(["Posts · 1"])
    end

    describe "past the limit" do
      before { 3.times { search(kind: "post") } }

      it "shows the limited state with the query still in the box", :aggregate_failures do
        expect(last_response.status).to eq(429)
        expect(page).to have_css(".sq-n.wait h2", text: "Too many searches at once")
        expect(page).to have_field("q", with: "zeppelin")
        expect(page).to have_no_css(".sq-g, .sq-w")
      end

      it "links to writing and projects", :aggregate_failures do
        expect(page).to have_link("Browse writing", href: "/writing")
        expect(page).to have_link("Browse projects", href: "/projects")
      end

      it "keeps the limited page out of shared caches" do
        expect(last_response.headers["Cache-Control"].to_s).not_to include("s-maxage")
      end

      it "records no attempt past the limit" do
        expect(attempts).to eq(2)
      end

      it "still searches for another visitor" do
        search("203.0.113.10")

        expect(last_response.status).to eq(200)
      end
    end
  end
end

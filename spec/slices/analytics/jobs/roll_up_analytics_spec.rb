# frozen_string_literal: true

require "digest"

RSpec.describe Analytics::Jobs::RollUpAnalytics, :frozen_clock do
  let(:day) { Blog::TimeZone.today - 1 }
  let(:today) { Blog::TimeZone.today }
  let(:visitor_hash) { Digest::SHA256.hexdigest("203.0.113.7 Mozilla/5.0") }

  def analytics_rollup = Blog::Types::SyncName["analytics_rollup"]

  def click(view, link_host: "docs.example", link_path: "/guide", **)
    create(:analytics_click, event_id: view.id, link_host:, link_path:, **)
  end

  def clicks_of(path, on = day)
    rows = rollup_repo.analytics_rollup_clicks.on(on).for_path(path).order(:link_host, :link_path).to_a

    rows.map { it.to_h.values_at(:link_host, :link_path, :clicks) }
  end

  def countries(on = day) = rollup_repo.countries(from: on, to: on).map(&:to_h)

  def devices_of(path, on = day)
    rows = rollup_repo.analytics_rollup_devices.on(on).for_path(path).order(:device_class).to_a

    rows.map { it.to_h.values_at(:device_class, :views, :visitors) }
  end

  def event(*traits, on: day, **) = create(:analytics_event, *traits, occurred_at: noon(on), **)

  def event_repo = Analytics::Slice["repos.analytics_event_repo"]

  def failure = sync_state_queries.failure(analytics_rollup)

  def kept = event_repo.analytics_events.order(:occurred_at, :id).to_a.map(&:id)

  def month_of(on) = Date.new(on.year, on.month, 1)

  def noon(on) = Blog::TimeZone.day_start(on) + (12 * 3_600)

  def page_rows(table, key, path, on = day)
    rows = rollup_repo.public_send(table).on(on).for_path(path).order(key).to_a

    rows.map { it.to_h.values_at(key, :views, :visitors) }
  end

  def paths(on = day) = rollup_repo.top_paths(from: on, to: on).map(&:to_h)

  def read_throughs(on = day)
    rollup_repo.analytics_rollup_paths.on(on).order(:path).to_a.to_h { [it.path, it.read_throughs] }
  end

  def referrers(on = day) = rollup_repo.referrers(from: on, to: on).map(&:to_h)

  def roll_up = described_class.new.perform

  def rollup(on, **) = create(:analytics_rollup, day: on, **)

  def rollup_repo = Analytics::Slice["repos.analytics_rollup_repo"]

  def scroll_depths_of(path, on = day)
    rows = rollup_repo.analytics_rollup_scroll_depths.on(on).for_path(path).order(:scroll_depth).to_a

    rows.map { it.to_h.values_at(:scroll_depth, :views, :visitors) }
  end

  def sources_of(path, on = day)
    rows = rollup_repo.analytics_rollup_sources.on(on).for_path(path).order(:source).to_a

    rows.map { it.to_h.values_at(:source, :views, :visitors) }
  end

  def stored_visitors(table, key, on = day)
    rollup_repo.public_send(table).on(on).order(key).to_a.to_h { [it[key], it.visitors] }
  end

  def sync_state_mutations = Record::Slice["repos.sync_state_mutations"]
  def sync_state_queries = Record::Slice["repos.sync_state_queries"]

  describe "yesterday" do
    it "stores the day's totals" do
      event(visitor_hash:, read_seconds: 90)
      event(visitor_hash:, read_seconds: 30)
      roll_up

      expect(rollup_repo.by_day(day)).to have_attributes(views: 2, visitors: 1, read_seconds: 120)
    end

    it "stores the per-path figures" do
      event(path: "/writing/hello", title: "Hello", visitor_hash:, read_seconds: 90)
      roll_up

      expect(paths).to eq(
        [{ path: "/writing/hello", title: "Hello", views: 1, visitors: 1, read_seconds: 90, bounces: 1 }],
      )
    end

    it "takes a path's title from its latest titled view" do
      event(path: "/writing/hello", title: "Old")
      create(:analytics_event, path: "/writing/hello", title: "New", occurred_at: noon(day) + 60)
      create(:analytics_event, path: "/writing/hello", title: nil, occurred_at: noon(day) + 120)
      roll_up

      expect(paths.first).to include(title: "New")
    end

    it "counts no bounce for a visitor who read a second page" do
      event(path: "/writing/hello", visitor_hash:)
      event(path: "/writing/other", visitor_hash:)
      roll_up

      expect(paths.map { it[:bounces] }).to eq([0, 0])
    end

    it "stores the referrers, with a direct visit under no host" do
      event(referrer_host: "news.example")
      event(:direct)
      roll_up

      expect(referrers.map { it.values_at(:host, :views, :visitors) })
        .to contain_exactly(["news.example", 1, 1], [nil, 1, 1])
    end

    it "stores the countries, with an unknown one under no code" do
      event(country_code: "JP")
      event(:unknown_country)
      roll_up

      expect(countries.map { it.values_at(:country_code, :views, :visitors) })
        .to contain_exactly(["JP", 1, 1], [nil, 1, 1])
    end

    it "stores each referrer's distinct visitors" do
      2.times { event(referrer_host: "news.example", visitor_hash:) }
      event(referrer_host: "news.example")
      event(:direct, visitor_hash:)
      roll_up

      expect(stored_visitors(:analytics_rollup_referrers, :host)).to eq("news.example" => 2, nil => 1)
    end

    it "stores each country's distinct visitors" do
      2.times { event(country_code: "JP", visitor_hash:) }
      event(country_code: "JP")
      event(:unknown_country, visitor_hash:)
      roll_up

      expect(stored_visitors(:analytics_rollup_countries, :country_code)).to eq("JP" => 2, nil => 1)
    end

    it "counts a visitor who came from two hosts once under each" do
      event(referrer_host: "news.example", visitor_hash:)
      event(referrer_host: "blog.example", visitor_hash:)
      event(referrer_host: "blog.example", visitor_hash:)
      roll_up

      expect(stored_visitors(:analytics_rollup_referrers, :host)).to eq("blog.example" => 1, "news.example" => 1)
    end

    describe "the sources" do
      before do
        event(path: "/writing/hello", source: "reddit", visitor_hash:)
        event(path: "/writing/other", source: "reddit", visitor_hash:)
        event(path: "/writing/other", source: "feed")
        event(path: "/writing/other")
        roll_up
      end

      it "stores the whole site's under no path, each reader once" do
        expect(sources_of(nil)).to eq([["feed", 1, 1], ["reddit", 2, 1]])
      end

      it "stores each page's under its own path" do
        expect(sources_of("/writing/hello")).to eq([["reddit", 1, 1]])
      end

      it "leaves out the views with no ref" do
        expect(sources_of("/writing/other")).to eq([["feed", 1, 1], ["reddit", 1, 1]])
      end
    end

    describe "each page's referrers and countries" do
      before do
        2.times { event(path: "/writing/hello", referrer_host: "news.example", country_code: "JP", visitor_hash:) }
        event(path: "/writing/hello", referrer_host: "news.example", country_code: "US")
        event(:direct, :unknown_country, path: "/writing/hello")
        event(path: "/writing/other", referrer_host: "news.example", country_code: "JP", visitor_hash:)
        roll_up
      end

      it "stores a page's referrers, with a direct visit under no host" do
        expect(page_rows(:analytics_rollup_page_referrers, :host, "/writing/hello"))
          .to eq([["news.example", 3, 2], [nil, 1, 1]])
      end

      it "stores a page's countries, with an unknown one under no code" do
        expect(page_rows(:analytics_rollup_page_countries, :country_code, "/writing/hello"))
          .to eq([["JP", 2, 1], ["US", 1, 1], [nil, 1, 1]])
      end

      it "stores each page apart", :aggregate_failures do
        expect(page_rows(:analytics_rollup_page_referrers, :host, "/writing/other")).to eq([["news.example", 1, 1]])
        expect(page_rows(:analytics_rollup_page_countries, :country_code, "/writing/other")).to eq([["JP", 1, 1]])
      end
    end

    describe "the scroll depths" do
      before do
        [0, 50, 100].each { event(path: "/writing/hello", scroll_depth: it, visitor_hash:) }
        event(path: "/writing/hello", scroll_depth: 100)
        event(path: "/writing/other", scroll_depth: 50, visitor_hash:)
        event(path: "/writing/old", scroll_depth: nil)
        roll_up
      end

      it "stores each page's views at each deepest depth" do
        expect(scroll_depths_of("/writing/hello")).to eq([[0, 1, 1], [50, 1, 1], [100, 2, 2]])
      end

      it "stores another page apart" do
        expect(scroll_depths_of("/writing/other")).to eq([[50, 1, 1]])
      end

      it "leaves out the views from before the site tracked scrolling" do
        expect(scroll_depths_of("/writing/old")).to be_empty
      end
    end

    describe "the read-throughs" do
      def read(path = "/writing/hello", scroll_depth: 75, read_seconds: 30, **)
        event(path:, scroll_depth:, read_seconds:, **)
      end

      it "counts a view that scrolled to 75% and read for 30 seconds" do
        read
        roll_up

        expect(read_throughs).to eq("/writing/hello" => 1)
      end

      it "counts a view that went past both marks" do
        read(scroll_depth: 100, read_seconds: 300)
        roll_up

        expect(read_throughs).to eq("/writing/hello" => 1)
      end

      it "leaves out a view one second short" do
        read(read_seconds: 29)
        roll_up

        expect(read_throughs).to eq("/writing/hello" => 0)
      end

      it "leaves out a view that read long but stopped at half the page" do
        read(scroll_depth: 50, read_seconds: 60)
        roll_up

        expect(read_throughs).to eq("/writing/hello" => 0)
      end

      it "leaves out a reader whose scroll and read time came from two views" do
        read(scroll_depth: 75, read_seconds: 5, visitor_hash:)
        read(scroll_depth: 25, read_seconds: 60, visitor_hash:)
        roll_up

        expect(read_throughs).to eq("/writing/hello" => 0)
      end

      it "counts a reader who read a post through twice once for the day" do
        2.times { read(visitor_hash:) }
        roll_up

        expect(read_throughs).to eq("/writing/hello" => 1)
      end

      it "counts each reader and each page apart" do
        read(visitor_hash:)
        read
        read("/writing/other", visitor_hash:)
        roll_up

        expect(read_throughs).to eq("/writing/hello" => 2, "/writing/other" => 1)
      end
    end

    describe "the clicks" do
      before do
        hello = event(path: "/writing/hello")
        2.times { click(hello) }
        click(event(path: "/writing/hello"), link_host: "code.example", link_path: "/repo")
        click(event(path: "/writing/other"))
        roll_up
      end

      it "stores each post's clicks on each link" do
        expect(clicks_of("/writing/hello")).to eq([["code.example", "/repo", 1], ["docs.example", "/guide", 2]])
      end

      it "stores another post apart" do
        expect(clicks_of("/writing/other")).to eq([["docs.example", "/guide", 1]])
      end
    end

    it "files a click under the day of its view" do
      click(event(path: "/writing/hello"), occurred_at: Blog::TimeZone.day_start(today) + 60)
      roll_up

      expect(clicks_of("/writing/hello")).to eq([["docs.example", "/guide", 1]])
    end

    describe "the devices" do
      before do
        event(path: "/writing/hello", device_class: "in-app", visitor_hash:)
        event(path: "/writing/other", device_class: "in-app", visitor_hash:)
        event(path: "/writing/other", device_class: "desktop")
        event(path: "/writing/other")
        roll_up
      end

      it "stores the whole site's under no path, each reader once" do
        expect(devices_of(nil)).to eq([["desktop", 1, 1], ["in-app", 2, 1]])
      end

      it "stores each page's under its own path" do
        expect(devices_of("/writing/hello")).to eq([["in-app", 1, 1]])
      end

      it "leaves out the views with no class" do
        expect(devices_of("/writing/other")).to eq([["desktop", 1, 1], ["in-app", 1, 1]])
      end
    end

    it "leaves today's events for tomorrow's run" do
      create(:analytics_event, occurred_at: Blog::TimeZone.day_start(today))
      roll_up

      expect(rollup_repo.by_day(day)).to have_attributes(views: 0)
    end

    it "counts the first moment of the day" do
      create(:analytics_event, occurred_at: Blog::TimeZone.day_start(day))
      roll_up

      expect(rollup_repo.by_day(day)).to have_attributes(views: 1)
    end

    it "stores a day with no events" do
      roll_up

      expect(rollup_repo.by_day(day)).to have_attributes(views: 0, visitors: 0, read_seconds: 0)
    end
  end

  describe "the month's reach" do
    let(:month) { month_of(day) }
    let(:reader) { "a" * 64 }

    it "counts each reader once for the month so far, site-wide and for each path" do
      event(on: month, path: "/writing/hello", month_visitor_hash: reader)
      event(path: "/writing/other", month_visitor_hash: reader)
      event(path: "/writing/other", month_visitor_hash: "b" * 64)
      roll_up

      expect(rollup_repo.reach_in(month)).to eq(nil => 2, "/writing/hello" => 1, "/writing/other" => 2)
    end

    it "leaves a reader from the month before out of this month" do
      event(on: month - 1, month_visitor_hash: reader)
      event(month_visitor_hash: "b" * 64)
      roll_up

      expect(rollup_repo.reach_in(month)).to include(nil => 1)
    end

    it "stores the same reach run twice" do
      event(month_visitor_hash: reader)
      2.times { roll_up }

      expect(rollup_repo.reach_in(month)).to include(nil => 1)
    end

    it "stores no reach for a month whose start the raw visits no longer hold" do
      old = ((today - 120)..(today - 95)).find { it.mday != 1 }
      event(on: old)
      roll_up

      expect(rollup_repo.reach_in(month_of(old))).to be_empty
    end
  end

  describe "run twice" do
    def page_origins
      [
        page_rows(:analytics_rollup_page_referrers, :host, "/writing/hello"),
        page_rows(:analytics_rollup_page_countries, :country_code, "/writing/hello"),
      ]
    end

    before do
      view = event(path: "/writing/hello", referrer_host: "news.example", country_code: "JP", source: "feed")
      click(view)
    end

    it "stores the same totals" do
      2.times { roll_up }

      expect(rollup_repo.by_day(day)).to have_attributes(views: 1, visitors: 1)
    end

    it "stores the same rows", :aggregate_failures do
      roll_up
      stored = [paths, referrers, countries, sources_of(nil), page_origins, clicks_of("/writing/hello")]
      roll_up

      expect([paths, referrers, countries, sources_of(nil), page_origins, clicks_of("/writing/hello")]).to eq(stored)
    end
  end

  describe "a day an earlier run missed" do
    it "rolls up the day between the newest rollup and yesterday" do
      rollup(day - 2)
      event(on: day - 1)
      roll_up

      expect(rollup_repo.by_day(day - 1)).to have_attributes(views: 1)
    end

    it "rolls up yesterday in the same run" do
      rollup(day - 2)
      event(on: day - 1)
      event
      roll_up

      expect(rollup_repo.by_day(day)).to have_attributes(views: 1)
    end

    it "rolls up a day the events ran dry on" do
      rollup(day - 2)
      roll_up

      expect(rollup_repo.by_day(day - 1)).to have_attributes(views: 0, visitors: 0)
    end

    it "fills every day a run that skipped nights left behind" do
      rollup(day - 3)
      event(on: day - 2)
      roll_up

      expect(rollup_repo.days(from: day - 2, to: day).map(&:day)).to eq([day - 2, day - 1, day])
    end

    it "starts at the oldest event it still holds, not at the newest rollup" do
      rollup(day - 200)
      event(on: day - 3)
      roll_up

      expect(rollup_repo.by_day(day - 100)).to be_nil
    end

    it "leaves a day it already rolled up alone" do
      rollup(day - 1, views: 5, visitors: 3)
      roll_up

      expect(rollup_repo.by_day(day - 1)).to have_attributes(views: 5, visitors: 3)
    end
  end

  describe "the prune" do
    def feed_reader_hash(day)
      feed_reader_hashes.dataset.insert(day:, path: "/writing.atom", reader_hash: Digest::SHA256.hexdigest(day.to_s))
    end

    def feed_reader_hashes = Analytics::Slice["repos.feed_fetch_repo"].feed_reader_hashes

    it "deletes the events older than 90 days once their day is rolled up" do
      event(on: today - 91)
      roll_up

      expect(kept).to be_empty
    end

    it "keeps the rollups for the days it pruned" do
      rollup(today - 91, views: 9, visitors: 5)
      event(on: today - 91)
      roll_up

      expect(rollup_repo.by_day(today - 91)).to have_attributes(views: 9)
    end

    it "rolls a day up before the prune takes its events" do
      event(on: today - 91)
      roll_up

      expect(rollup_repo.by_day(today - 91)).to have_attributes(views: 1)
    end

    it "deletes the whole day that falls out of the window" do
      create(:analytics_event, occurred_at: Blog::TimeZone.day_start(today - 89) - 1)
      roll_up

      expect(kept).to be_empty
    end

    it "keeps the first moment of the day at the edge of the window" do
      edge = create(:analytics_event, occurred_at: Blog::TimeZone.day_start(today - 89))
      roll_up

      expect(kept).to eq([edge.id])
    end

    it "keeps the clicks for the days it pruned", :aggregate_failures do
      click(event(path: "/writing/hello", on: today - 91))
      roll_up

      expect(event_repo.analytics_clicks.count).to be_zero
      expect(clicks_of("/writing/hello", today - 91)).to eq([["docs.example", "/guide", 1]])
    end

    it "deletes the feed reader hashes older than 90 days" do
      [90, 89].each { feed_reader_hash(today - it) }
      roll_up

      expect(feed_reader_hashes.to_a.map(&:day)).to eq([today - 89])
    end

    it "stops at the first day no run rolled up" do
      [95, 93].each { rollup(today - it) }
      events = [95, 94, 93].map { event(on: today - it).id }
      roll_up

      expect(kept).to eq(events.drop(1))
    end
  end

  describe "the reader counts" do
    let(:reader_repo) { Analytics::Slice["repos.post_reader_hash_repo"] }

    def hashes(path) = reader_repo.post_reader_hashes.for_paths(path).count

    def post(slug, days_ago) = create(:post, :published, slug:, published_at: Time.now - (days_ago * 86_400))

    def readers(path, count) = count.times { create(:post_reader_hash, path:) }

    def saved = reader_repo.post_reader_counts.to_a.to_h { [it.path, it.readers] }

    describe "of a post past its first 12 months" do
      before do
        post("old", 370)
        readers("/writing/old", 3)
      end

      it "saves the count of its readers" do
        roll_up

        expect(saved).to eq("/writing/old" => 3)
      end

      it "deletes its hashes" do
        roll_up

        expect(hashes("/writing/old")).to be_zero
      end

      it "keeps the count the same on the next night" do
        2.times { roll_up }

        expect(saved).to eq("/writing/old" => 3)
      end
    end

    describe "of a post within its first 12 months" do
      before do
        post("new", 360)
        readers("/writing/new", 2)
        roll_up
      end

      it "keeps its hashes" do
        expect(hashes("/writing/new")).to eq(2)
      end

      it "saves no count" do
        expect(saved).to be_empty
      end
    end

    describe "of a path that matches no post" do
      before do
        post("new", 30)
        readers("/writing/gone", 2)
        roll_up
      end

      it "deletes its hashes" do
        expect(hashes("/writing/gone")).to be_zero
      end

      it "saves no count" do
        expect(saved).to be_empty
      end
    end

    describe "of a post whose slug changed" do
      def rename(post, slug)
        row = reader_repo.post_reader_hashes.dataset.db[:posts].where(id: post.id)
        row.update(status: "draft")
        row.update(slug:)
        row.update(status: "published")
      end

      before do
        renamed = post("old-slug", 30)
        readers("/writing/old-slug", 2)
        readers("/writing/new-slug", 1)
        rename(renamed, "new-slug")
        roll_up
      end

      it "deletes the old path's hashes" do
        expect(hashes("/writing/old-slug")).to be_zero
      end

      it "keeps the new path's hashes" do
        expect(hashes("/writing/new-slug")).to eq(1)
      end
    end

    it "leaves a draft's hashes alone" do
      create(:post, slug: "draft")
      readers("/writing/draft", 1)
      roll_up

      expect(hashes("/writing/draft")).to eq(1)
    end

    describe "when the delete breaks" do
      before do
        post("old", 370)
        readers("/writing/old", 3)
        allow(reader_repo).to(receive(:post_reader_hashes).and_wrap_original { break_closed(it.call) })
        replace_component("repos.post_reader_hash_repo", reader_repo)
      end

      def break_closed(relation)
        allow(relation).to(receive(:closed).and_wrap_original { |closed, since| break_delete(closed.call(since)) })
        relation
      end

      def break_delete(relation)
        allow(relation).to receive(:delete).and_raise(Sequel::DatabaseError, "PG::DiskFull")
        relation
      end

      def roll_up_failing
        roll_up
      rescue Sequel::DatabaseError
        nil
      end

      it "keeps the hashes and saves no count", :aggregate_failures do
        roll_up_failing

        expect(hashes("/writing/old")).to eq(3)
        expect(saved).to be_empty
      end
    end
  end

  it "clears an earlier failure once a run gets through" do
    sync_state_mutations.record_failure(analytics_rollup, :rollup_failed)
    roll_up

    expect(failure).to be_nil
  end

  describe "a run that breaks" do
    let(:crash) { -> { raise Sequel::DatabaseError, "PG::UndefinedTable" } }

    def roll_up_failing
      roll_up
    rescue Sequel::DatabaseError
      nil
    end

    it "leaves the rollup that broke where the operator reads it, message and all" do
      replace_component("operations.roll_up_analytics", crash)
      roll_up_failing

      expect(failure).to include(message: "PG::UndefinedTable", reason: "rollup_failed", sync: analytics_rollup)
    end

    it "tells a prune that broke from a rollup that broke" do
      replace_component("operations.prune_analytics_events", crash)
      roll_up_failing

      expect(failure).to include(reason: "prune_failed")
    end

    it "tells the operator the reader counts failed, message and all" do
      reader_repo = Analytics::Slice["repos.post_reader_hash_repo"]
      allow(reader_repo).to receive(:save_counts).and_raise(Sequel::DatabaseError, "PG::DiskFull")
      replace_component("repos.post_reader_hash_repo", reader_repo)
      roll_up_failing

      expect(failure).to include(reason: "readers_failed", message: "PG::DiskFull")
    end

    it "still fails the run, so the error reaches the log with its backtrace" do
      replace_component("operations.roll_up_analytics", crash)

      expect { roll_up }.to raise_error(Sequel::DatabaseError, /PG::UndefinedTable/)
    end

    it "holds the prune back until a day rolls up, so it deletes nothing it hasn't summed" do
      old = event(on: today - 91)
      replace_component("operations.roll_up_analytics", crash)
      roll_up_failing

      expect(kept).to eq([old.id])
    end

    it "counts the nights it has been failing" do
      replace_component("operations.roll_up_analytics", crash)
      2.times { roll_up_failing }

      expect(failure).to include(count: 2)
    end
  end
end

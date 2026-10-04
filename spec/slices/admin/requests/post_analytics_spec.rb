# frozen_string_literal: true

require "digest"

RSpec.describe "Admin post analytics", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:today) { Blog::TimeZone.today }
  let(:post) { create(:post, :published, title: "Hello", slug: "hello") }

  def card(title) = page.find(".card", text: title)

  def counts(title) = card(title).all(".meter-count").map(&:text)

  def curve = card("First 30 days")

  def message(key) = i18n.t(key, scope: "ui")

  def names(title) = card(title).all(".meter-name").map(&:text)

  def points(name) = curve.find("polyline.curve-#{name}", visible: :all)[:points].split

  def published(slug, on:) = create(:post, :published, slug:, published_at: Blog::TimeZone.day_start(on) + 43_200)

  def readings = curve.all("tbody tr", visible: :all).map { |row| row.all("th, td", visible: :all).map(&:text) }

  def roll_up(day, **)
    create(:analytics_rollup, day:)
    create(:analytics_rollup_path, day:, path: "/writing/hello", title: "Hello", read_seconds: 0, **)
  end

  def roll_up_breakdowns(day, path: "/writing/hello")
    create(:analytics_rollup_page_referrer, day:, path:, host: "news.example", views: 3, visitors: 2)
    create(:analytics_rollup_page_referrer, :direct, day:, path:, views: 5, visitors: 3)
    create(:analytics_rollup_page_country, day:, path:, country_code: "US", views: 6, visitors: 4)
    create(:analytics_rollup_page_country, :unknown, day:, path:, views: 2, visitors: 1)
    create(:analytics_rollup_device, day:, path:, device_class: "mobile", views: 5, visitors: 3)
    create(:analytics_rollup_device, day:, path:, device_class: "desktop", views: 3, visitors: 2)
    create(:analytics_rollup_device, day:, path: nil, device_class: "tablet", views: 9, visitors: 9)
    create(:analytics_rollup_source, day:, path:, source: "mastodon", views: 4, visitors: 3)
  end

  def roll_up_clicks
    links = { "docs.example" => 2, "code.example" => 5 }

    [today - 1, today - 8].each do |day|
      links.each do |link_host, clicks|
        create(:analytics_rollup_click, day:, path: "/writing/hello", link_host:, link_path: "/guide", clicks:)
      end
      create(:analytics_rollup_click, day:, path: "/writing/other", clicks: 9)
    end
  end

  def roll_up_days
    roll_up(today - 1, views: 8, visitors: 5, bounces: 2, read_throughs: 3)
    roll_up(today - 8, views: 100, visitors: 40, bounces: 10, read_throughs: 20)
    create(:analytics_rollup_path, day: today - 1, path: "/writing/other", views: 50, visitors: 30, bounces: 0)
    roll_up_breakdowns(today - 1)
    roll_up_scroll_depths(today - 1)
    roll_up_clicks
  end

  def roll_up_scroll_depths(day)
    { 0 => 2, 25 => 2, 50 => 2, 75 => 1, 100 => 3 }.each do |scroll_depth, views|
      create(:analytics_rollup_scroll_depth, day:, path: "/writing/hello", scroll_depth:, views:, visitors: 1)
    end
  end

  def rolled(slug, on:, visitors:)
    day = create(:analytics_rollup, day: on).day

    create(:analytics_rollup_path, day:, path: "/writing/#{slug}", views: visitors, visitors:, bounces: 0)
  end

  def show(post) = get("/admin/posts/#{post.id}/analytics")

  def stat(key) = page.find(".stat", text: key)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "with rolled up days" do
      before do
        roll_up_days
        get "/admin/posts/#{post.id}/analytics"
      end

      it "answers with the page" do
        expect(last_response).to be_ok
      end

      it "titles the page with the post" do
        expect(page).to have_css(".page-head-title", exact_text: "Hello")
      end

      it "names the range and the path under the title" do
        expect(page).to have_css(".page-head-sub", exact_text: "Last 7 days · /writing/hello")
      end

      it "totals the post's views over the range" do
        expect(stat("Page views")).to have_css(".stat-value", exact_text: "8")
      end

      it "totals the post's visitors over the range" do
        expect(stat("Visitors")).to have_css(".stat-value", exact_text: "5")
      end

      it "divides the bounces by the visitors for the bounce rate" do
        expect(stat("Visitors")).to have_css(".stat-change", exact_text: "40% bounce rate")
      end

      it "totals the post's read-throughs over the range" do
        expect(stat("Read-throughs")).to have_css(".stat-value", exact_text: "3")
      end

      it "shows the share of views that scrolled to each depth", :aggregate_failures do
        expect(names("Scroll depth")).to eq(%w[25% 50% 75% 100%])
        expect(counts("Scroll depth")).to eq(%w[80% 60% 40% 30%])
      end

      it "ranks the post's referrers by visitors, naming a direct visit", :aggregate_failures do
        expect(names("Referrers")).to eq(%w[direct news.example])
        expect(counts("Referrers")).to eq(%w[3 2])
      end

      it "ranks the post's countries by visitors, naming one it could not place", :aggregate_failures do
        expect(names("Geography")).to eq(%w[US unknown])
        expect(counts("Geography")).to eq(%w[4 1])
      end

      it "ranks the post's devices by visitors, leaving out the site's" do
        expect(names("Devices")).to eq(%w[mobile desktop])
      end

      it "lists the post's sources" do
        expect(names("Sources")).to eq(%w[mastodon])
      end

      it "ranks the post's outbound links by clicks, most first", :aggregate_failures do
        expect(names("Outbound clicks")).to eq(%w[code.example/guide docs.example/guide])
        expect(counts("Outbound clicks")).to eq(%w[5 2])
      end

      it "links back to the editor" do
        expect(page).to have_css("a[href='/admin/posts/#{post.id}/edit']", text: "Edit")
      end
    end

    describe "with rolled up days over a longer range" do
      before do
        roll_up_days
        get "/admin/posts/#{post.id}/analytics", range: "14"
      end

      it "counts the days the range covers" do
        expect(stat("Page views")).to have_css(".stat-value", exact_text: "108")
      end

      it "counts the clicks the range covers" do
        expect(counts("Outbound clicks")).to eq(%w[10 4])
      end

      it "counts the read-throughs the range covers" do
        expect(stat("Read-throughs")).to have_css(".stat-value", exact_text: "23")
      end

      it "keeps the chosen range in the control" do
        expect(page).to have_css(".seg input[name='range'][value='14'][checked]")
      end

      it "posts the range back to the same page" do
        expect(page).to have_css("form[action='/admin/posts/#{post.id}/analytics']")
      end
    end

    describe "with today's views not rolled up yet" do
      def hashed(name) = Digest::SHA256.hexdigest(name)

      before do
        events = %w[one one two].map do |reader|
          create(
            :analytics_event,
            path: "/writing/hello", visitor_hash: hashed(reader), month_visitor_hash: hashed("month-#{reader}"),
            scroll_depth: 75, read_seconds: 30,
          )
        end
        create(:analytics_event, path: "/writing/other", month_visitor_hash: hashed("month-three"))
        create(:analytics_click, event_id: events.last.id)
        get "/admin/posts/#{post.id}/analytics"
      end

      it "counts today's views" do
        expect(stat("Page views")).to have_css(".stat-value", exact_text: "3")
      end

      it "counts today's outbound clicks" do
        expect(names("Outbound clicks")).to eq(%w[docs.example/guide])
      end

      it "counts each of this month's readers once" do
        expect(stat("Readers")).to have_css(".stat-value", exact_text: "2")
      end

      it "names the month the readers count in" do
        expect(stat("Readers")).to have_css(".stat-change", exact_text: "in #{today.strftime('%B %Y')}")
      end

      it "counts each reader who read it through once a day" do
        expect(stat("Read-throughs")).to have_css(".stat-value", exact_text: "2")
      end
    end

    describe "with no data at all" do
      before { get "/admin/posts/#{post.id}/analytics" }

      it "shows zeroed stats" do
        expect(page.all(".stat-value").map(&:text)).to eq(%w[0 0 0 0 0])
      end

      it "shows a zero bounce rate" do
        expect(stat("Visitors")).to have_css(".stat-change", exact_text: "0% bounce rate")
      end

      it "says there is nothing in the cards", :aggregate_failures do
        %w[
          components.analytics.scroll_card.empty views.posts.analytics.no_devices views.posts.analytics.no_sources
          views.posts.analytics.no_referrers views.posts.analytics.no_countries views.posts.analytics.no_clicks
        ].each { expect(page).to have_css(".empty", exact_text: message(it)) }
      end
    end

    describe "unique readers" do
      def unique_readers = stat("Unique readers")

      def year_old_post = create(:post, :published, slug: "old", published_at: Time.now - (400 * 86_400))

      it "counts the readers of a post in its first 12 months", :aggregate_failures do
        2.times { create(:post_reader_hash, path: "/writing/hello") }
        get "/admin/posts/#{post.id}/analytics"

        expect(unique_readers).to have_css(".stat-value", exact_text: "2")
        expect(unique_readers).to have_css(".stat-change", exact_text: "in its first 12 months")
      end

      it "marks a saved count as final", :aggregate_failures do
        create(:post_reader_count, path: "/writing/old", readers: 1234)
        get "/admin/posts/#{year_old_post.id}/analytics"

        expect(unique_readers).to have_css(".stat-value", exact_text: "1,234")
        expect(unique_readers).to have_css(".stat-change", exact_text: "final count")
      end

      it "says a post older than 12 months with no saved count has none", :aggregate_failures do
        get "/admin/posts/#{year_old_post.id}/analytics"

        expect(unique_readers).to have_css(".stat-value", exact_text: "None")
        expect(unique_readers).to have_css(".stat-change", exact_text: "no count kept")
      end
    end

    describe "first 30 days of a three day old post" do
      before do
        young = published("young", on: today - 2)
        rolled("young", on: today - 2, visitors: 7)
        show(young)
      end

      it "draws the post's readers per day, with zero for a day nobody read" do
        expect(readings.map { it.first(2) }).to eq([%w[1 7], %w[2 0], %w[3 0]])
      end

      it "draws a point for each day" do
        expect(points("post").size).to eq(3)
      end
    end

    describe "first 30 days beside the median post" do
      before do
        old = published("old", on: today - 3)
        published("young", on: today - 1)
        rolled("old", on: today - 3, visitors: 4)
        rolled("young", on: today - 1, visitors: 8)
        show(old)
      end

      it "names the median curve" do
        expect(curve).to have_css(".curve-key", exact_text: "Median post")
      end

      it "takes the middle count, leaving out posts too young for a day" do
        expect(readings.map(&:last)).to eq(%w[6 0 0 0])
      end

      it "draws the median as far as the oldest post" do
        expect(points("median").size).to eq(4)
      end
    end

    describe "first 30 days" do
      it "draws as many days as a young post has had" do
        show(published("young", on: today - 9))

        expect(points("post").size).to eq(10)
      end

      it "stops at day 30 for an older post" do
        show(published("old", on: today - 60))

        expect(points("post").size).to eq(30)
      end

      it "says a draft has no curve" do
        show(create(:post, :draft))

        expect(curve).to have_css(".empty", exact_text: message("components.analytics.first_days_card.empty"))
      end
    end

    it "answers 404 for a post that isn't there" do
      get "/admin/posts/404404/analytics"

      expect(last_response.status).to eq(404)
    end
  end

  describe "signed out" do
    it "redirects to sign-in" do
      get "/admin/posts/#{post.id}/analytics"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end
  end
end

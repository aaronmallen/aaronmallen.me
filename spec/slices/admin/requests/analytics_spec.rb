# frozen_string_literal: true

RSpec.describe "Admin analytics", :frozen_clock, type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:today) { Blog::TimeZone.today }

  def bars = page.all(".chart-bar").map { it[:style] }

  def lede = page.find(".page-head-sub").text

  def message(key) = i18n.t(key, scope: "ui")

  def meter_card(title) = page.find(".card", text: title)

  def tips = page.all(".chart-tip").map(&:text)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "with rolled up days" do
      before do
        create(:analytics_rollup, day: today, views: 10, visitors: 5, read_seconds: 300)
        create(:analytics_rollup, day: today - 1, views: 30, visitors: 20, read_seconds: 600)
        create(:analytics_rollup, day: today - 8, views: 100, visitors: 40, read_seconds: 800)
        get "/admin/analytics", range: "7"
      end

      it "heads the page with the range" do
        expect(lede).to include("in the last 7 days").and end_with("Self-hosted rollups, no third-party scripts.")
      end

      it "answers with the page titled Analytics", :aggregate_failures do
        expect(last_response).to be_ok
        expect(page).to have_title("Analytics | Admin | #{Hanami.app.settings.owner_name}")
      end

      it "switches the range on the analytics screen", :aggregate_failures do
        expect(page).to have_css("form[action='/admin/analytics'] [role=radiogroup][aria-label=Range]")
        expect(page).to have_checked_field("range", with: "7")
      end

      it "totals the page views and the visitors over the range" do
        expect(lede).to start_with("40 views from 25 visitors")
      end

      it "averages the read time over the page views" do
        expect(lede).to include("0:22 average read")
      end

      it "divides the views by the visitors for pages per visit" do
        expect(lede).to include("1.6 pages per visit")
      end

      it "compares the views against the previous range of the same length" do
        expect(lede).to include("down 60% on the previous 7 days")
      end

      it "draws no stat strip" do
        expect(page).to have_no_css(".stat")
      end

      it "draws one bar per day in the range" do
        expect(bars.size).to eq(7)
      end

      it "scales each bar to the peak day" do
        expect(bars).to eq((["height: 0%"] * 5) + ["height: 100%", "height: 33%"])
      end

      it "names the peak in the card head" do
        expect(page).to have_css(".chart-peak", exact_text: "peak 30")
      end

      it "labels each bar with its day and figures" do
        expect(tips.last).to eq("#{today.strftime('%b %-d')} · 10 views · 5 visitors")
      end

      it "labels the first, middle and last day under the bars" do
        expect(page.find(".chart-dates").all("span").map(&:text))
          .to eq([today - 6, today - 3, today].map { it.strftime("%b %-d") })
      end
    end

    describe "with a longer range" do
      before do
        create(:analytics_rollup, day: today, views: 10, visitors: 5, read_seconds: 300)
        create(:analytics_rollup, day: today - 8, views: 100, visitors: 40, read_seconds: 800)
      end

      it "totals the days the range covers" do
        get "/admin/analytics", range: "14"

        expect(lede).to start_with("110 views")
      end

      it "draws one bar per day" do
        get "/admin/analytics", range: "30"

        expect(bars.size).to eq(30)
      end

      it "keeps the chosen range in the control" do
        get "/admin/analytics", range: "30"

        expect(page).to have_css(".seg input[name='range'][value='30'][checked]")
      end

      it "offers the 7, 14 and 30 day ranges" do
        get "/admin/analytics", range: "7"

        expect(page.all(".seg-option").map(&:text)).to eq(%w[7d 14d 30d])
      end

      it "falls back to 30 days for a range it doesn't know" do
        get "/admin/analytics", range: "90"

        expect(page).to have_css(".seg input[name='range'][value='30'][checked]")
      end
    end

    describe "without a previous range" do
      before do
        create(:analytics_rollup, day: today, views: 10, visitors: 5, read_seconds: 300)
        get "/admin/analytics", range: "7"
      end

      it "says there is no prior period" do
        expect(lede).to include("with no prior period to compare")
      end

      it "names no rise or fall" do
        expect(lede).not_to match(/\b(up|down) \d/)
      end
    end

    describe "with today's events not rolled up yet" do
      before do
        create(:analytics_rollup, day: today - 1, views: 4, visitors: 2, read_seconds: 40)
        create(:analytics_event, path: "/writing/hello", title: "Hello", read_seconds: 60)
        create(:analytics_event, path: "/writing/hello", title: "Hello", read_seconds: 30)
        get "/admin/analytics", range: "7"
      end

      it "counts today's raw events in the totals" do
        expect(lede).to start_with("6 views")
      end

      it "counts today's raw events in the chart" do
        expect(tips.last).to eq("#{today.strftime('%b %-d')} · 2 views · 2 visitors")
      end

      it "lists today's paths in the top pages" do
        expect(page).to have_css(".tbl-title", text: "Hello")
      end
    end

    describe "with earlier days not rolled up yet" do
      def noon(day) = Blog::TimeZone.day_start(day) + (12 * 3_600)

      before do
        create(:analytics_rollup, day: today - 3, views: 4, visitors: 2, read_seconds: 40)
        create(:analytics_event, path: "/writing/rolled", occurred_at: noon(today - 3))
        create(:analytics_event, path: "/writing/hello", title: "Hello", read_seconds: 60, occurred_at: noon(today - 2))
        2.times { create(:analytics_event, path: "/writing/late", occurred_at: noon(today - 1)) }
        get "/admin/analytics", range: "7"
      end

      it "counts every unrolled day's raw events in the totals" do
        expect(lede).to start_with("7 views")
      end

      it "counts each unrolled day's raw events on its own day in the chart" do
        expect(tips.last(3).map { it.split(" · ", 2).last })
          .to eq(["1 view · 1 visitor", "2 views · 2 visitors", "0 views · 0 visitors"])
      end

      it "reads a rolled up day from its rollup" do
        expect(tips[-4]).to eq("#{(today - 3).strftime('%b %-d')} · 4 views · 2 visitors")
      end

      it "lists an unrolled day's paths in the top pages" do
        expect(page).to have_css(".tbl-title", text: "Hello")
      end

      it "leaves out the raw events of a rolled up day" do
        expect(page).to have_no_css(".tbl-path", text: "/writing/rolled")
      end
    end

    describe "with paths, referrers and countries" do
      before do
        create(:analytics_rollup, day: today, views: 12, visitors: 8, read_seconds: 600)
        create(
          :analytics_rollup_path,
          day: today, path: "/writing/hello", title: "Hello", views: 8, visitors: 6, read_seconds: 480, bounces: 3,
        )
        create(:analytics_rollup_referrer, day: today, host: "news.example", views: 7, visitors: 2)
        create(:analytics_rollup_referrer, :direct, day: today, views: 5, visitors: 5)
        create(:analytics_rollup_country, day: today, country_code: "US", country_name: "United States", views: 9,
                                          visitors: 3)
        create(:analytics_rollup_country, :unknown, day: today, views: 3, visitors: 3)
        get "/admin/analytics", range: "7"
      end

      it "shows the page's title and path" do
        expect(page).to have_css(".tbl-page", text: "Hello").and(have_css(".tbl-path", text: "/writing/hello"))
      end

      it "shows the page's views, average time and bounce rate" do
        expect(page.all("tbody .tbl-c.num").map(&:text)).to eq(["8", "1:00", "50%"])
      end

      it "names a referrer with no host as direct" do
        expect(meter_card("Referrers")).to have_css(".meter-name", text: "direct")
      end

      it "ranks the referrers by visitors" do
        expect(meter_card("Referrers").all(".meter-name").map(&:text)).to eq(%w[direct news.example])
      end

      it "counts each referrer's visitors" do
        expect(meter_card("Referrers").all(".meter-count").map(&:text)).to eq(%w[5 2])
      end

      it "scales each referrer against the top one" do
        expect(meter_card("Referrers").all(".meter-fill").map { it[:style] })
          .to eq(["width: 100%", "width: 40%"])
      end

      it "ranks the countries by visitors, then views" do
        expect(meter_card("Geography").all(".meter-name").map(&:text)).to eq(["United States", "unknown"])
      end

      it "shows a country's code when it has no name" do
        create(:analytics_rollup_country, day: today, country_code: "DE", views: 1, visitors: 1)
        get "/admin/analytics", range: "7"

        expect(meter_card("Geography")).to have_css(".meter-name", exact_text: "DE")
      end

      it "counts each country's visitors" do
        expect(meter_card("Geography").all(".meter-count").map(&:text)).to eq(%w[3 3])
      end

      it "still counts views for the top pages and the total", :aggregate_failures do
        expect(page.first("tbody .tbl-c.num")).to have_text("8")
        expect(lede).to start_with("12 views")
      end

      it "names a country with no code as unknown" do
        expect(meter_card("Geography")).to have_css(".meter-name", text: "unknown")
      end

      it "colors the referrer and geography meters apart", :aggregate_failures do
        expect(meter_card("Referrers")).to have_css(".meter.blue")
        expect(meter_card("Geography")).to have_css(".meter.violet")
      end
    end

    describe "with more paths, referrers and countries than a list holds" do
      let(:codes) { %w[AU BR CA DE ES FR GB IN JP MX US] }

      before do
        create(:analytics_rollup, day: today, views: 500, visitors: 300, read_seconds: 0)
        11.times do |n|
          create(:analytics_rollup_path, day: today, path: "/writing/post-#{n}", views: n + 1, visitors: 1, bounces: 0)
          create(:analytics_rollup_referrer, day: today, host: "site-#{n}.example", views: 30 - n, visitors: n + 1)
          create(:analytics_rollup_country, day: today, country_code: codes[n], views: 30 - n, visitors: n + 1)
        end
        get "/admin/analytics", range: "7"
      end

      it "lists the top 10 paths by views" do
        expect(page.all(".tbl-path").map(&:text)).to eq(10.downto(1).map { "/writing/post-#{it}" })
      end

      it "lists the top 10 referrers by visitors" do
        expect(meter_card("Referrers").all(".meter-name").map(&:text)).to eq(10.downto(1).map { "site-#{it}.example" })
      end

      it "lists the top 10 countries by visitors" do
        expect(meter_card("Geography").all(".meter-name").map(&:text)).to eq(codes.drop(1).reverse)
      end
    end

    describe "with a range that reaches past the event window" do
      before do
        create(:analytics_rollup, day: today - 5, views: 20, visitors: 10, read_seconds: 0)
        create(:analytics_rollup, day: today - 1, views: 20, visitors: 10, read_seconds: 0)
        create(:analytics_rollup_referrer, day: today - 5, host: "news.example", views: 6)
        create(:analytics_rollup_referrer, day: today - 1, host: "news.example", views: 2, visitors: 1)
        create(:analytics_rollup_referrer, day: today - 5, host: "old.example", views: 9)
        create(:analytics_rollup_country, day: today - 5, country_code: "DE", views: 4)
        create(:analytics_event, referrer_host: "news.example", country_code: "US")
        get "/admin/analytics", range: "7"
      end

      it "answers with the page and ranks a referrer with no counted day last", :aggregate_failures do
        expect(last_response).to be_ok
        expect(meter_card("Referrers").all(".meter-name").map(&:text)).to eq(%w[news.example old.example])
      end

      it "sums the visitors of the days that counted them and shows none for the rest" do
        expect(meter_card("Referrers").all(".meter-count").map(&:text)).to eq(["2", ""])
      end

      it "leaves the bar empty for a row with no visitor figure" do
        expect(meter_card("Geography").all(".meter-fill").map { it[:style] }).to eq(["width: 100%", "width: 0%"])
      end
    end

    describe "with events across the week" do
      let(:sunday) { today - (today.wday.zero? ? 7 : today.wday) }

      def at(day, hour, minute = 0) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour, minute)

      def cell(hour, weekday) = grid.all("tbody tr")[weekday].all(".heat-cell")[hour]

      def grid = page.find("table.heat")

      before do
        2.times { create(:analytics_event, occurred_at: at(sunday, 23, 30)) }
        create(:analytics_event, occurred_at: at(sunday + 1, 9))
        create(:analytics_event, occurred_at: at(today - 95, 9))
        get "/admin/analytics", range: "7"
      end

      it "draws a row for every day of the week" do
        expect(grid.all("tbody tr").size).to eq(7)
      end

      it "draws a cell for every hour of the day in each row" do
        expect(grid.all("tbody tr").map { it.all(".heat-cell").size }.uniq).to eq([24])
      end

      it "heads the rows Monday to Sunday" do
        expect(grid.all("tbody .heat-day").map(&:text)).to eq(%w[Mon Tue Wed Thu Fri Sat Sun])
      end

      it "heads the columns with the hours" do
        expect(grid.all("thead .heat-hour").map(&:text)).to eq(Array.new(24) { format("%02d", it) })
      end

      it "names the window and the time zone in the card head" do
        expect(page.find(".card", text: "Readers by hour"))
          .to have_css(".chart-peak", exact_text: "last 90 days · Chicago time")
      end

      it "counts a late Sunday event in Sunday's 23 row, whatever its UTC date" do
        expect(cell(23, 6)).to have_css(".sr-only", exact_text: "2 readers")
      end

      it "counts the Monday morning event in Monday's 9 row" do
        expect(cell(9, 0)).to have_css(".sr-only", exact_text: "1 reader")
      end

      it "leaves out events older than the window" do
        expect(grid.all(".heat-cell .sr-only").sum { it.text.to_i }).to eq(3)
      end

      it "names the count of an empty cell" do
        expect(cell(0, 0)).to have_css(".sr-only", exact_text: "0 readers")
      end

      it "shades each cell against the busiest one", :aggregate_failures do
        expect(cell(23, 6)[:style]).to eq("--heat: 100%")
        expect(cell(9, 0)[:style]).to eq("--heat: 50%")
        expect(cell(0, 0)[:style]).to eq("--heat: 0%")
      end
    end

    describe "with feed subscribers" do
      def aggregators(part) = feed_card.all(".feed-aggregators .meter-#{part}").map(&:text)

      def feed_card = page.find(".card", text: "Feed subscribers")

      def readings = feed_card.all("tbody tr").map { it.all("th, td").map(&:text) }

      def short(day) = day.strftime("%b %-d")

      before do
        create(:feed_subscriber, day: today, aggregator: "feedly", subscribers: 40)
        create(:feed_subscriber, day: today, path: "/writing/tags/ruby.atom", aggregator: "feedly", subscribers: 2)
        create(:feed_subscriber, day: today - 1, aggregator: "inoreader", subscribers: 9)
        create(:feed_subscriber, day: today - 2, aggregator: "feedly", subscribers: 38)
        create(:feed_subscriber, day: today - 9, aggregator: "newsblur", subscribers: 5)
        create(:feed_reader, day: today, readers: 3)
        create(:feed_reader, day: today, path: "/writing/tags/ruby.atom", readers: 1)
        create(:feed_reader, day: today - 2, readers: 2)
        get "/admin/analytics", range: "7"
      end

      it "lists a day for each day in the range" do
        expect(readings.size).to eq(7)
      end

      it "adds each day's aggregator counts and other readers across the feeds" do
        expect(readings.last(3)).to eq([[short(today - 2), "40"], [short(today - 1), "9"], [short(today), "46"]])
      end

      it "counts a day with nothing as zero" do
        expect(readings.first).to eq([short(today - 6), "0"])
      end

      it "names the last whole day in the card head, leaving out today" do
        expect(feed_card).to have_css(".chart-peak", exact_text: "latest 9")
      end

      it "draws a point for each day" do
        expect(feed_card.find("polyline")[:points].split.size).to eq(7)
      end

      it "names each aggregator, most subscribers first" do
        expect(aggregators(:name)).to eq(%w[feedly inoreader])
      end

      it "counts each aggregator's latest count across its feeds" do
        expect(aggregators(:count)).to eq(%w[42 9])
      end

      it "takes in a longer range the aggregators it covers" do
        get "/admin/analytics", range: "14"

        expect(aggregators(:name)).to eq(%w[feedly inoreader newsblur])
      end
    end

    describe "with feed subscribers yesterday and no fetch yet today" do
      before do
        create(:feed_subscriber, day: today - 1, aggregator: "feedly", subscribers: 40)
        get "/admin/analytics", range: "7"
      end

      it "reads yesterday's count in the card head" do
        expect(page.find(".card", text: "Feed subscribers")).to have_css(".chart-peak", exact_text: "latest 40")
      end
    end

    describe "with webmentions" do
      before do
        hello = create(:post, :published, title: "Hello")
        other = create(:post, :published, title: "Other")
        older = create(:post, :published, title: "Older")
        3.times { create(:webmention, post: hello, received_at: Blog::TimeZone.day_start(today)) }
        create(:webmention, :approved, post: other, received_at: Blog::TimeZone.day_start(today - 1))
        create(:webmention, :approved, post: older, received_at: Blog::TimeZone.day_start(today - 8))
        get "/admin/analytics", range: "7"
      end

      it "counts the mentions received over the range and those still waiting in the card head" do
        expect(meter_card("Webmentions per post")).to have_css(".chart-peak", exact_text: "4 received · 3 pending")
      end

      it "lists the posts with mentions, most first" do
        expect(meter_card("Webmentions per post").all(".meter-name").map(&:text)).to eq(%w[Hello Other])
      end

      it "counts each post's mentions over the range" do
        expect(meter_card("Webmentions per post").all(".meter-count").map(&:text)).to eq(%w[3 1])
      end

      it "colors the mention meters apart from the other cards" do
        expect(meter_card("Webmentions per post")).to have_css(".meter.pink")
      end

      it "leaves out a post whose only mention landed before the range" do
        expect(meter_card("Webmentions per post")).to have_no_css(".meter-name", text: "Older")
      end
    end

    it "counts one pending mention in the singular" do
      create(:webmention, :reply, post: create(:post, :published))
      get "/admin/analytics"

      expect(meter_card("Webmentions per post")).to have_css(".chart-peak", exact_text: "1 received · 1 pending")
    end

    describe "with an ignored webmention" do
      before do
        hello = create(:post, :published, title: "Hello")
        create(:webmention, :approved, post: hello, received_at: Blog::TimeZone.day_start(today))
        create(:webmention, :ignored, post: hello, received_at: Blog::TimeZone.day_start(today))
        get "/admin/analytics", range: "7"
      end

      it "counts it as received" do
        expect(meter_card("Webmentions per post")).to have_css(".chart-peak", text: "2 received")
      end

      it "counts it against its post" do
        expect(meter_card("Webmentions per post").all(".meter-count").map(&:text)).to eq(%w[2])
      end
    end

    describe "with more mentioned posts than the card holds" do
      before do
        11.times { |n| create(:webmention, post: create(:post, :published, title: "Post #{n}")) }
        get "/admin/analytics", range: "7"
      end

      it "lists only as many posts as the other side cards" do
        expect(meter_card("Webmentions per post").all(".meter-name").size).to eq(10)
      end
    end

    describe "with a top page that is a post" do
      let!(:post) { create(:post, :published, slug: "hello", title: "Hello") }

      before do
        create(:analytics_rollup, day: today, views: 12, visitors: 6)
        { "/writing/hello" => "Hello", "/about" => "About" }.each do |path, title|
          create(:analytics_rollup_path, day: today, path:, title:, views: 6, visitors: 3, bounces: 0)
        end
        get "/admin/analytics", range: "7"
      end

      it "links the post to its analytics" do
        expect(page).to have_link("Hello", href: "/admin/posts/#{post.id}/analytics")
      end

      it "leaves a page that is no post unlinked" do
        expect(page).to have_no_link("About")
      end
    end

    describe "with scroll depths" do
      def scroll_card = page.find(".card", text: "Scroll depth")

      before do
        create(:analytics_rollup, day: today, views: 4, visitors: 4)
        { "/writing/hello" => [100, 1], "/writing/other" => [25, 3] }.each do |path, (scroll_depth, views)|
          create(:analytics_rollup_scroll_depth, day: today, path:, scroll_depth:, views:, visitors: views)
        end
        get "/admin/analytics", range: "7"
      end

      it "shares out how far the views on every page reached" do
        expect(scroll_card.all(".meter-count").map(&:text)).to eq(%w[100% 25% 25% 25%])
      end
    end

    describe "with scroll depths not rolled up yet" do
      before do
        create(:analytics_event, path: "/writing/hello", scroll_depth: 75)
        create(:analytics_event, path: "/writing/other", scroll_depth: 25)
        get "/admin/analytics", range: "7"
      end

      it "counts today's views on every page" do
        expect(page.find(".card", text: "Scroll depth").all(".meter-count").map(&:text)).to eq(%w[100% 50% 50% 0%])
      end
    end

    describe "with no data at all" do
      before { get "/admin/analytics" }

      it "answers with the page and zeroed figures", :aggregate_failures do
        expect(last_response).to be_ok
        expect(lede).to start_with("0 views from 0 visitors").and include("0:00 average read")
      end

      it "still draws a bar for every day" do
        expect(bars).to eq(["height: 0%"] * 30)
      end

      it "counts no feed subscribers" do
        expect(page.find(".card", text: "Feed subscribers")).to have_css(".chart-peak", exact_text: "latest 0")
      end

      it "says there is nothing in the cards", :aggregate_failures do
        expect(page).to have_css(".empty", exact_text: message("components.analytics.pages_card.empty"))
        expect(page).to have_css(".empty", exact_text: message("components.analytics.referrers_card.empty"))
        expect(page).to have_css(".empty", exact_text: message("components.analytics.countries_card.empty"))
        expect(page).to have_css(".empty", exact_text: message("views.analytics.show.no_mentions"))
        expect(page).to have_css(".empty", exact_text: message("components.analytics.feed_card.no_aggregators"))
      end

      it "says there is no scroll depth yet" do
        expect(page).to have_css(".empty", exact_text: message("components.analytics.scroll_card.empty"))
      end
    end
  end
end

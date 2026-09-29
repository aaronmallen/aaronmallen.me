# frozen_string_literal: true

RSpec.describe "Admin analytics", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:today) { Blog::TimeZone.today }

  def bars = page.all(".chart-bar").map { it[:style] }

  def message(key) = i18n.t(key, scope: "ui")

  def meter_card(title) = page.find(".card", text: title)

  def stat(key) = page.find(".stat", text: key)

  def tips = page.all(".chart-tip").map(&:text)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "with rolled up days" do
      before do
        create(:analytics_rollup, day: today, views: 10, visitors: 5, read_seconds: 300)
        create(:analytics_rollup, day: today - 1, views: 30, visitors: 20, read_seconds: 600)
        create(:analytics_rollup, day: today - 8, views: 100, visitors: 40, read_seconds: 800)
        get "/admin/analytics"
      end

      it "answers with the page" do
        expect(last_response).to be_ok
      end

      it "heads the page with the range" do
        expect(page).to have_css(".page-head-sub", text: "Last 7 days · self-hosted rollups, no third-party scripts")
      end

      it "titles the page Analytics" do
        expect(page).to have_title("Analytics | Admin | #{Blog::Owner.full_name}")
      end

      it "totals the page views over the range" do
        expect(stat("Page views")).to have_css(".stat-value", exact_text: "40")
      end

      it "totals the visitors over the range" do
        expect(stat("Visitors")).to have_css(".stat-value", exact_text: "25")
      end

      it "averages the read time over the page views" do
        expect(stat("Avg. read")).to have_css(".stat-value", exact_text: "0:22")
      end

      it "divides the views by the visitors for pages per visit" do
        expect(stat("Visitors")).to have_css(".stat-change", text: "1.6 pages per visit")
      end

      it "compares the views against the previous range of the same length" do
        expect(stat("Page views")).to have_css(".stat-change.down", text: "-60% vs. previous 7 days")
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

        expect(stat("Page views")).to have_css(".stat-value", exact_text: "110")
      end

      it "draws one bar per day" do
        get "/admin/analytics", range: "30"

        expect(bars.size).to eq(30)
      end

      it "keeps the chosen range in the control" do
        get "/admin/analytics", range: "30"

        expect(page).to have_css(".seg input[name='range'][value='30'][checked]")
      end

      it "falls back to 7 days for a range it doesn't know" do
        get "/admin/analytics", range: "90"

        expect(page).to have_css(".seg input[name='range'][value='7'][checked]")
      end
    end

    describe "without a previous range" do
      before do
        create(:analytics_rollup, day: today, views: 10, visitors: 5, read_seconds: 300)
        get "/admin/analytics"
      end

      it "says there is no prior period" do
        expect(stat("Page views")).to have_css(".stat-change", text: "no prior period")
      end

      it "leaves the change unmarked" do
        expect(stat("Page views")).to have_no_css(".stat-change.down")
      end
    end

    describe "with today's events not rolled up yet" do
      before do
        create(:analytics_rollup, day: today - 1, views: 4, visitors: 2, read_seconds: 40)
        create(:analytics_event, path: "/writing/hello", title: "Hello", read_seconds: 60)
        create(:analytics_event, path: "/writing/hello", title: "Hello", read_seconds: 30)
        get "/admin/analytics"
      end

      it "counts today's raw events in the totals" do
        expect(stat("Page views")).to have_css(".stat-value", exact_text: "6")
      end

      it "counts today's raw events in the chart" do
        expect(tips.last).to eq("#{today.strftime('%b %-d')} · 2 views · 2 visitors")
      end

      it "lists today's paths in the top pages" do
        expect(page).to have_css(".tbl-title", text: "Hello")
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
        create(:analytics_rollup_country, day: today, country_code: "US", views: 9, visitors: 3)
        create(:analytics_rollup_country, :unknown, day: today, views: 3, visitors: 3)
        get "/admin/analytics"
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
        expect(meter_card("Geography").all(".meter-name").map(&:text)).to eq(%w[US unknown])
      end

      it "counts each country's visitors" do
        expect(meter_card("Geography").all(".meter-count").map(&:text)).to eq(%w[3 3])
      end

      it "still counts views for the top pages and the total", :aggregate_failures do
        expect(page.first("tbody .tbl-c.num")).to have_text("8")
        expect(stat("Page views")).to have_css(".stat-value", exact_text: "12")
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
        get "/admin/analytics"
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
        get "/admin/analytics"
      end

      it "answers with the page" do
        expect(last_response).to be_ok
      end

      it "ranks a referrer with no counted day last" do
        expect(meter_card("Referrers").all(".meter-name").map(&:text)).to eq(%w[news.example old.example])
      end

      it "sums the visitors of the days that counted them and shows none for the rest" do
        expect(meter_card("Referrers").all(".meter-count").map(&:text)).to eq(["2", ""])
      end

      it "leaves the bar empty for a row with no visitor figure" do
        expect(meter_card("Geography").all(".meter-fill").map { it[:style] }).to eq(["width: 100%", "width: 0%"])
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
        get "/admin/analytics"
      end

      it "counts the mentions received over the range" do
        expect(stat("Webmentions")).to have_css(".stat-value", exact_text: "4")
      end

      it "counts the mentions still waiting as the change" do
        expect(stat("Webmentions")).to have_css(".stat-change", text: "3 pending")
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

    describe "with more mentioned posts than the card holds" do
      before do
        11.times { |n| create(:webmention, post: create(:post, :published, title: "Post #{n}")) }
        get "/admin/analytics"
      end

      it "lists only as many posts as the other side cards" do
        expect(meter_card("Webmentions per post").all(".meter-name").size).to eq(10)
      end
    end

    describe "with no data at all" do
      before { get "/admin/analytics" }

      it "answers with the page" do
        expect(last_response).to be_ok
      end

      it "shows zeroed stats" do
        expect(page.all(".stat-value").map(&:text)).to eq(["0", "0", "0:00", "0"])
      end

      it "still draws a bar for every day" do
        expect(bars).to eq(["height: 0%"] * 7)
      end

      it "says there is nothing in the cards", :aggregate_failures do
        expect(page).to have_css(".empty", exact_text: message("components.analytics.pages_card.empty"))
        expect(page).to have_css(".empty", exact_text: message("views.analytics.show.no_referrers"))
        expect(page).to have_css(".empty", exact_text: message("views.analytics.show.no_countries"))
        expect(page).to have_css(".empty", exact_text: message("views.analytics.show.no_mentions"))
      end
    end
  end

  describe "signed out" do
    it "redirects the dashboard to sign-in" do
      get "/admin/analytics"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end
  end
end

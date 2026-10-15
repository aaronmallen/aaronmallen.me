# frozen_string_literal: true

RSpec.describe "Admin performance", :frozen_clock, type: :request do
  let(:quick_job) { ["Quick::Job", "", "50 ms", "50 ms", "1", "3.0", "2 ms"] }
  let(:slow_job) { ["Spec::Job", "", "200 ms", "290 ms", "2", "3.0", "2 ms"] }
  let(:slow_route) { ["GET /admin/tasks", "", "1,000 ms", "1,000 ms", "1", "5.0", "100 ms"] }
  let(:today) { Blog::TimeZone.today }
  let(:writing_route) { ["GET /writing/:slug", "", "250 ms", "385 ms", "4", "2.0", "25 ms"] }

  def card(title) = page.find(".card", text: title)

  def cells(row) = row.all("td").map(&:text)

  def chart_tips = page.all(".perf-col .chart-tip").map(&:text)

  def job_row(duration, job: "Spec::Job", on: today)
    relation(:performance_jobs).insert(
      job:, outcome: "succeeded", duration:, query_count: 3, query_time: 1.5, occurred_at: noon(on),
    )
  end

  def lede(view, count) = Admin::Slice["i18n"].t(["ui.views.performance", view, "lede"].join("."), count:)

  def noon(on) = Blog::TimeZone.day_start(on) + (12 * 3_600)

  def page = Capybara.string(last_response.body)

  def page_row(load, lcp: nil, route: "/writing/:slug")
    relation(:performance_pages).insert(
      route:, device_class: "desktop", ttfb: 10, dom_content_loaded: 20, load:, lcp:, occurred_at: noon(today),
    )
  end

  def relation(name) = Performance::Slice["db.rom"].relations[name]

  def request_row(duration, on: today, route: "/writing/:slug", verb: "GET", status: 200, query_count: 2)
    relation(:performance_requests).insert(
      route:, verb:, status:, duration:, query_count:, query_time: duration / 10, occurred_at: noon(on),
    )
  end

  def rows(title) = card(title).all("tbody tr")

  def short(day) = day.strftime("%b %-d")

  def tab(name) = page.find(".perf-tabs-list a", exact_text: name)

  describe "signed in" do
    before { sign_in_to_admin }

    it "answers with the page titled Performance under Insights", :aggregate_failures do
      get "/admin/performance"

      expect(page).to have_title("Performance | Admin | #{Hanami.app.settings.owner_name}")
      expect(page).to have_css("a.pill-nav-link[aria-current='page']", text: "Insights")
      expect(page).to have_css(".screen-tab[aria-current='page']", exact_text: "performance")
    end

    it "offers the screen in the command palette" do
      get "/admin"

      expect(page).to have_css("[data-palette-href='/admin/performance']", text: "performance")
    end

    it "says so when nothing ran", :aggregate_failures do
      get "/admin/performance"

      expect(card("Routes")).to have_css(".empty")
      expect(card("Jobs")).to have_css(".empty")
    end

    it "lists routes by p95 with p50, count, queries and query time" do
      [100.0, 200.0, 300.0, 400.0].each { request_row(it) }
      request_row(1_000.0, route: "/admin/tasks", query_count: 5)
      get "/admin/performance"

      expect(rows("Routes").map { cells(it).first(7) }).to eq([slow_route, writing_route])
    end

    it "heads the page with the range over timings kept on this server", :aggregate_failures do
      request_row(100.0)
      get "/admin/performance", range: "14"
      expect(page).to have_css(".page-head-sub", exact_text: lede("show", 14))
      expect(rows("Routes")).to have(1).item
    end

    it "heads the routes card with the count and order" do
      [100.0, 200.0].each { request_row(it) }
      request_row(1_000.0, route: "/admin/tasks")
      get "/admin/performance"

      expect(card("Routes")).to have_css(".card-side", exact_text: "2 routes · slowest p95 first")
    end

    it "groups the route columns under Server and Browser", :aggregate_failures do
      request_row(100.0)
      get "/admin/performance"

      groups = card("Routes").first("thead tr").all("th").map { [it.text, it[:colspan]] }
      expect(groups).to eq([["Server", "6"], ["Browser · GET only", "4"]])
      expect(card("Routes")).to have_css("th.perf-key-col", exact_text: "p95")
    end

    it "draws each route's p50 to p95 spread on a square-root scale to the slowest p95" do
      request_row(1_000.0, route: "/admin/tasks")
      request_row(250.0)
      get "/admin/performance"

      spreads = rows("Routes").map { |row| row.all(".perf-spread i").map { it[:style] } }
      expect(spreads).to eq([["width: 100%", "width: 100%"], ["width: 50%", "width: 50%"]])
    end

    it "lists jobs by p95 the same way" do
      job_row(50.0, job: "Quick::Job")
      [100.0, 300.0].each { job_row(it) }
      get "/admin/performance"

      expect(rows("Jobs").map { cells(it) }).to eq([slow_job, quick_job])
    end

    it "heads the jobs card with the count of classes" do
      job_row(50.0, job: "Quick::Job")
      job_row(100.0)
      get "/admin/performance"

      expect(card("Jobs")).to have_css(".card-side", exact_text: "Sidekiq · 2 classes")
    end

    it "shows the browser load and LCP beside a route's server figures" do
      request_row(100.0)
      [900.0, 1_100.0].each { page_row(it, lcp: it / 2) }
      get "/admin/performance"

      expect(cells(rows("Routes").first).last(4)).to eq(["1,000 ms", "1,090 ms", "500 ms", "545 ms"])
    end

    it "shows no browser figures for a GET route the browser never timed" do
      request_row(100.0, route: "/feed.xml")
      page_row(900.0)
      get "/admin/performance"

      expect(cells(rows("Routes").first).last(4)).to eq(%w[none none none none])
    end

    it "hatches the browser cells of a route that is not a GET" do
      request_row(100.0, verb: "POST")
      page_row(900.0)
      get "/admin/performance"

      expect(rows("Routes").first).to have_css("td.perf-na[colspan='4']", exact_text: "GET only")
    end

    describe "the tab row" do
      it "selects Performance and links both tabs with the range", :aggregate_failures do
        get "/admin/performance", range: "7"

        expect(tab("Traffic")[:href]).to eq("/admin/analytics?range=7")
        expect(tab("Performance")[:"aria-current"]).to eq("page")
        expect(page).to have_css(".perf-tabs input[name='range'][value='7'][checked]")
      end

      it "selects Traffic on the analytics screen", :aggregate_failures do
        get "/admin/analytics", range: "14"

        expect(tab("Traffic")[:"aria-current"]).to eq("page")
        expect(tab("Performance")[:href]).to eq("/admin/performance?range=14")
      end

      it "keeps Performance selected on a route's requests and the route on a range switch", :aggregate_failures do
        get "/admin/performance/requests", route: "/writing/:slug", verb: "GET", range: "7"

        expect(tab("Performance")[:"aria-current"]).to eq("true")
        expect(page.find(".perf-tabs form")[:action]).to eq("/admin/performance/requests")
        expect(page).to have_field("route", type: :hidden, with: "/writing/:slug")
        expect(page).to have_field("verb", type: :hidden, with: "GET")
      end
    end

    describe "the server time chart" do
      before do
        [100.0, 300.0].each { request_row(it) }
        request_row(1_000.0, on: today - 6, route: "/admin/tasks")
        get "/admin/performance", range: "7"
      end

      it "draws a column per day, with a bar only on days with requests", :aggregate_failures do
        expect(page.all(".perf-col").size).to eq(7)
        expect(page.all(".perf-col .perf-bar").size).to eq(2)
      end

      it "scales the p95 bar to the slowest day and the p50 bar within it" do
        bars = page.all(".perf-col .perf-bar").map { [it[:style], it.find(".perf-fill-50")[:style]] }

        expect(bars).to eq([["height: 100%", "height: 100%"], ["height: 29%", "height: 69%"]])
      end

      it "labels each day with p50, p95 and its requests, and an empty day with none", :aggregate_failures do
        expect(chart_tips.last).to eq("#{short(today)} · p50 200 ms · p95 290 ms · 2 requests")
        expect(chart_tips[1]).to eq("#{short(today - 5)} · 0 requests")
      end

      it "names the peak for screen readers and marks the median day", :aggregate_failures do
        expect(page).to have_css(
          ".perf-chart[role='img'][aria-label='Server time per day: p95 peaked at 1,000 ms on #{short(today - 6)}']",
        )
        expect(page).to have_css(".perf-median", exact_text: "median day 1,000 ms")
        expect(page.all(".perf-chart-y span").map(&:text)).to eq(["1,000 ms", "500", "0"])
      end

      it "labels the first, middle and last day" do
        expect(page.all(".perf-chart-dates span").map(&:text)).to eq([today - 6, today - 3, today].map { short(it) })
      end
    end

    it "keeps to the chosen range", :aggregate_failures do
      request_row(100.0, on: today - 10)
      job_row(100.0, on: today - 10)
      get "/admin/performance", range: "7"

      expect(page).to have_checked_field("range", with: "7")
      expect(page).to have_css(".card .empty", count: 3)
    end

    it "counts a row from 10 days back in a 14 day range" do
      request_row(100.0, on: today - 10)
      get "/admin/performance", range: "14"

      expect(rows("Routes")).to have(1).item
    end

    describe "a route's slowest requests" do
      before do
        [100.0, 700.0, 300.0].each { request_row(it) }
        request_row(5_000.0, route: "/admin/tasks")
        request_row(9_000.0, on: today - 10)
        get "/admin/performance", range: "7"
        get page.find_link("GET /writing/:slug")[:href]
      end

      it "heads the page with the route", :aggregate_failures do
        expect(page).to have_css(".page-head h1 .perf-verb", exact_text: "GET")
        expect(page).to have_css(".page-head h1 .perf-path", exact_text: "/writing/:slug")
        expect(page).to have_css(".page-head-sub", exact_text: lede("requests", 7))
      end

      it "charts the route per day and heads the table with the rows shown of the total", :aggregate_failures do
        expect(card("This route per day")).to have_css(".card-side", text: "3 requests")
        expect(page.all(".perf-col .perf-bar").size).to eq(1)
        expect(card("Slowest requests")).to have_css(".card-side", exact_text: "3 of 3")
      end

      it "scales each time bar to the slowest request" do
        expect(rows("Slowest requests").map { it.find(".perf-time-bar i")[:style] })
          .to eq(["width: 100%", "width: 43%", "width: 14%"])
      end

      it "lists the route's requests in the range, slowest first" do
        expect(rows("Slowest requests").map { cells(it).drop(1) }).to eq(
          [["200", "700 ms", "2", "70 ms"], ["200", "300 ms", "2", "30 ms"], ["200", "100 ms", "2", "10 ms"]],
        )
      end

      it "links back to the screen with the range" do
        expect(page).to have_link("All routes", href: "/admin/performance?range=7")
      end
    end

    it "opens the requests no route served" do
      request_row(40.0, route: nil, status: 404)
      get "/admin/performance"
      get page.find_link("GET no route")[:href]

      expect(cells(rows("Slowest requests").first).drop(1)).to eq(["404", "40 ms", "2", "4 ms"])
    end

    it "marks a server error among a route's slowest requests", :aggregate_failures do
      request_row(900.0, status: 503)
      request_row(100.0)
      get "/admin/performance/requests", route: "/writing/:slug", verb: "GET"

      expect(page).to have_css(".perf-status.bad", exact_text: "503")
      expect(page).to have_css(".perf-status:not(.bad)", exact_text: "200")
    end
  end

  describe "signed out" do
    %w[/admin/performance /admin/performance/requests].each do |route|
      it "sends #{route} to sign-in" do
        get route

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
      end
    end
  end
end

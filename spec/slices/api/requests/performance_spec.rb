# frozen_string_literal: true

RSpec.describe "API performance", :frozen_clock, type: :request do
  let(:browser_pages) do
    [
      { "route" => "/writing", "load" => figures(900.0), "lcp" => nil, "ttfb" => figures(10.0),
        "dom_content_loaded" => figures(20.0) },
      { "route" => "/", "load" => figures(500.0), "lcp" => figures(300.0), "ttfb" => figures(10.0),
        "dom_content_loaded" => figures(20.0) },
    ]
  end
  let(:ranked_routes) do
    [
      { "route" => "/writing", "verb" => "POST", "count" => 1, "p50" => 90.0, "p95" => 90.0, "query_count" => 2,
        "query_time" => 0.3 },
      { "route" => "/writing", "verb" => "GET", "count" => 4, "p50" => 25.0, "p95" => 38.5, "query_count" => 8,
        "query_time" => 1.0 },
    ]
  end
  let(:today) { Blog::TimeZone.today }
  let(:yesterday) { today - 1 }

  def figures(value) = { "count" => 1, "p50" => value, "p95" => value }

  def job_row(duration, job: "Spec::Job", on: today)
    relation(:performance_jobs).insert(
      job:, outcome: "succeeded", duration:, query_count: 3, query_time: 1.5, occurred_at: noon(on),
    )
  end

  def mint(scopes) = API::Slice["operations.mint_token"].call(name: "Terminal", scopes:).value!.fetch(:value)

  def noon(on) = Blog::TimeZone.day_start(on) + (12 * 3_600)

  def page_row(load, route: "/", lcp: nil, on: today)
    relation(:performance_pages).insert(
      route:, device_class: "desktop", ttfb: 10, dom_content_loaded: 20, load:, lcp:, occurred_at: noon(on),
    )
  end

  def read(from: today, to: today, token: mint(%w[read]))
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{token}" }
    get "/api/v1/performance", { from: from.to_s, to: to.to_s }, headers
    JSON.parse(last_response.body)
  end

  def relation(name) = Performance::Slice["db.rom"].relations[name]

  def request_row(duration, route: "/writing", verb: "GET", on: today)
    relation(:performance_requests).insert(
      route:, verb:, status: 200, duration:, query_count: 2, query_time: 0.25, occurred_at: noon(on),
    )
  end

  def roll_up = Performance::Jobs::RollUpTiming.new.perform

  it "ranks routes by p95 with their p50, count and summed queries" do
    [10.0, 20.0, 30.0, 40.0].each { request_row(it) }
    request_row(90.0, verb: "POST")

    expect(read.fetch("routes")).to eq(ranked_routes)
  end

  it "ranks jobs by p95 the same way" do
    job_row(5.0, job: "Spec::Fast")
    [100.0, 200.0].each { job_row(it) }

    expect(read.fetch("jobs").map { it.values_at("job", "count", "p50", "p95", "query_count", "query_time") })
      .to eq([["Spec::Job", 2, 150.0, 195.0, 6, 3.0], ["Spec::Fast", 1, 5.0, 5.0, 3, 1.5]])
  end

  it "gives each page's browser figures, with null for a metric no browser sent" do
    page_row(500, lcp: 300)
    page_row(900, route: "/writing")

    expect(read.fetch("pages")).to eq(browser_pages)
  end

  it "weighs rolled up days and today's raw rows by their counts, counting a rolled day once" do
    [10.0, 10.0, 10.0].each { request_row(it, on: yesterday) }
    roll_up
    request_row(50.0)

    expect(read(from: yesterday).fetch("routes"))
      .to contain_exactly(include("count" => 4, "p50" => 20.0, "p95" => 20.0, "query_count" => 8))
  end

  it "leaves out timing from outside the range" do
    request_row(10.0, on: yesterday)
    job_row(10.0, on: yesterday)
    page_row(100, on: yesterday)

    expect(read.values_at("from", "to", "routes", "jobs", "pages")).to eq([today.iso8601, today.iso8601, [], [], []])
  end

  it "refuses a range that runs backwards" do
    read(from: today, to: yesterday)

    expect(last_response.status).to eq(422)
  end

  it "refuses a token without the read scope" do
    read(token: mint(%w[write]))

    expect(last_response.status).to eq(403)
  end

  it "answers read_performance over MCP with the same figures" do
    request_row(10.0)
    job_row(20.0)
    page_row(300, lcp: 200)

    expect(mcp_answer("read_performance", from: today.iso8601, to: today.iso8601)).to eq(read)
  end
end

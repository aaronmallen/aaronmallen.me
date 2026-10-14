# frozen_string_literal: true

RSpec.describe Performance::Jobs::RollUpTiming, :frozen_clock do
  let(:day) { Blog::TimeZone.today - 1 }
  let(:old) { Blog::TimeZone.today - 30 }
  let(:page_figures) do
    [["ttfb", 2, 0.1, 0.1], ["dom_content_loaded", 2, 0.2, 0.2], ["load", 2, 2.0, 2.9], ["lcp", 1, 0.5, 0.5]]
  end
  let(:request_figures) { [["/writing", "GET", 4, 2.5, 3.85], ["/writing", "POST", 1, 9.0, 9.0]] }

  def figures(name, *keys) = rolled(name).map { it.values_at(*keys, :count, :p50, :p95).map { round(it) } }

  def job_row(duration, on: day)
    relation(:performance_jobs).insert(
      job: "Spec::Job", outcome: "succeeded", duration:, query_count: 1, query_time: 0.5, occurred_at: noon(on),
    )
  end

  def noon(on) = Blog::TimeZone.day_start(on) + (12 * 3_600)

  def page_row(load, on: day, lcp: nil)
    relation(:performance_pages).insert(
      route: "/", device_class: "desktop", ttfb: 0.1, dom_content_loaded: 0.2, load:, lcp:, occurred_at: noon(on),
    )
  end

  def raw_counts = %i[performance_requests performance_jobs performance_pages].map { relation(it).count }

  def relation(name) = Performance::Slice["db.rom"].relations[name]

  def request_row(duration, on: day, route: "/writing", verb: "GET")
    relation(:performance_requests).insert(
      route:, verb:, status: 200, duration:, query_count: 2, query_time: 0.25, occurred_at: noon(on),
    )
  end

  def roll_up = described_class.new.perform

  def rolled(name) = relation(name).order(:id).to_a.map { it.to_h.except(:id, :created_at, :updated_at) }

  def rollups = %i[performance_rollup_requests performance_rollup_jobs performance_rollup_pages].map { rolled(it) }

  def round(value) = value.is_a?(Float) ? value.round(6) : value

  it "writes p50, p95 and count per route and verb" do
    [1.0, 2.0, 3.0, 4.0].each { request_row(it) }
    request_row(9.0, verb: "POST")
    roll_up

    expect(figures(:performance_rollup_requests, :route, :verb)).to eq(request_figures)
  end

  it "adds up the queries of each route" do
    [1.0, 2.0].each { request_row(it) }
    roll_up

    expect(rolled(:performance_rollup_requests)).to contain_exactly(include(day:, query_count: 4, query_time: 0.5))
  end

  it "keeps requests with no route in a row of their own" do
    request_row(1.0, route: nil)
    roll_up

    expect(rolled(:performance_rollup_requests)).to contain_exactly(include(route: nil, count: 1))
  end

  it "writes p50, p95 and count per job class" do
    [1.0, 3.0].each { job_row(it) }
    roll_up

    expect(figures(:performance_rollup_jobs, :job)).to eq([["Spec::Job", 2, 2.0, 2.9]])
  end

  it "adds up the queries of each job class" do
    [1.0, 3.0].each { job_row(it) }
    roll_up

    expect(rolled(:performance_rollup_jobs)).to contain_exactly(include(query_count: 2, query_time: 1.0))
  end

  it "writes p50, p95 and count per route and browser metric, skipping a missing LCP" do
    page_row(1.0, lcp: 0.5)
    page_row(3.0)
    roll_up

    expect(figures(:performance_rollup_pages, :metric)).to eq(page_figures)
  end

  it "rolls up every finished day since the last run and leaves today alone" do
    request_row(1.0, on: day - 2)
    request_row(1.0, on: day + 1)
    roll_up

    expect(relation(:performance_rollups).order(:day).pluck(:day)).to eq([day - 2, day - 1, day])
  end

  it "leaves the same rollup when it runs twice for one day" do
    [request_row(1.0), job_row(1.0), page_row(1.0)]
    roll_up

    expect { roll_up }.not_to(change { rollups })
  end

  it "deletes raw rows older than 30 days" do
    [request_row(1.0, on: old), job_row(1.0, on: old), page_row(1.0, on: old), request_row(2.0, on: old + 1)]
    roll_up

    expect(raw_counts).to eq([1, 0, 0])
  end

  it "keeps the rollups of the raw rows it deletes" do
    [request_row(1.0, on: old), job_row(1.0, on: old), page_row(1.0, on: old)]
    roll_up

    expect(rollups.map { |rows| rows.map { it[:day] }.uniq }).to eq([[old], [old], [old]])
  end
end

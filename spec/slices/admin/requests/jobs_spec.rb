# frozen_string_literal: true

RSpec.describe "Admin jobs", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }

  before { sign_in_to_admin }

  def counts = page.all(".jobs-count").to_h { [it.find("span").text, it.find("b").text] }

  def health = page.find(".jobs-health")

  def jobs_tab = page.find("nav[aria-label='Settings tabs'] a", text: "jobs").text

  def process(busy: 0, concurrency: 10, beat: Time.now - 3, quiet: "false")
    Sidekiq::Process.new("busy" => busy, "concurrency" => concurrency, "beat" => beat.to_f, "quiet" => quiet)
  end

  def processes(*found) = allow(Sidekiq::ProcessSet).to receive(:new).and_return(found)

  def stats(**) = allow(Sidekiq::Stats).to receive(:new).and_return(Spec::FakeStats.new(**))

  def visit = get("/admin/settings/jobs")

  def warning(key, **) = admin_t("ui.components.jobs.warnings.#{key}", **)

  describe "with a worker running" do
    before do
      processes(process(busy: 3), process(busy: 2, beat: Time.now - 9))
      stats(
        enqueued: 214, scheduled_size: 6, retry_size: 3, dead_size: 2,
        queue_summaries: [Sidekiq::Stats::QueueSummary.new(name: "default", size: 214, latency: 252.0, paused: false)],
      )
      visit
    end

    it "draws the jobs tab of the Settings page", :aggregate_failures do
      expect(page).to have_css(".page-head h1", exact_text: "Settings")
      expect(page).to have_css("nav[aria-label='Settings tabs'] a[aria-current='page'][href='/admin/settings/jobs']")
    end

    it "says the worker is working, with its newest heartbeat and process count", :aggregate_failures do
      expect(health.find("h2")).to have_text("Working")
      expect(health.find(".jobs-status-meta time")["datetime"]).to eq(Blog::TimeZone.local(Time.now - 3).iso8601)
      expect(health.find(".jobs-status-meta")).to have_text("2 processes")
    end

    it "counts busy of concurrency, enqueued, latency, scheduled, retries and dead" do
      expect(counts).to eq(
        "busy" => "5 of 20", "enqueued" => "214", "latency" => "4m", "scheduled" => "6", "retries" => "3",
        "dead" => "2",
      )
    end

    it "counts retries plus dead jobs on the tab label" do
      expect(jobs_tab).to eq("jobs 5")
    end

    it "shows no warning" do
      expect(page).to have_no_css(".jobs-banner")
    end
  end

  describe "the last seven days" do
    let(:today) { Time.now.utc.to_date }

    before do
      days = { today => { processed: 1_240, failed: 3 }, (today - 1) => { processed: 900, failed: 0 } }
      history = Spec::FakeHistory.new(days)
      allow(Sidekiq::Stats::History).to receive(:new).with(7).and_return(history)
      visit
    end

    it "shows processed and failed today", :aggregate_failures do
      expect(page.find(".jobs-big:not(.jobs-big-small)")).to have_text("1,240 processed")
      expect(page.find(".jobs-big.jobs-failed")).to have_text("3 failed")
    end

    it "draws a bar for each day, today last", :aggregate_failures do
      bars = page.all(".jobs-bar")

      expect(bars.size).to eq(7)
      expect(bars.last[:class]).to include("jobs-bar-today")
      expect(bars.last).to have_css("i.jobs-bar-failed")
    end

    it "names each day's figures for a screen reader" do
      expect(page.find(".jobs-bars")["aria-label"]).to include("1,240 processed, 3 failed")
    end
  end

  describe "with Redis down" do
    before do
      allow(Sidekiq::Stats).to receive(:new).and_raise(RedisClient::CannotConnectError, "Connection refused")
      visit
    end

    it "warns with the error" do
      expect(page.find(".jobs-banner[role='alert']"))
        .to have_text("RedisClient::CannotConnectError: Connection refused")
    end

    it "reads every count as unknown" do
      expect(counts.values.uniq).to eq(["unknown"])
    end

    it "marks the tab label" do
      expect(jobs_tab).to eq("jobs !")
    end

    it "keeps the other Settings tabs working" do
      get "/admin/settings/security"

      expect([last_response.status, jobs_tab]).to eq([200, "jobs !"])
    end
  end

  describe "with no worker process" do
    def finish_job(at)
      Performance::Slice["db.rom"].relations[:performance_jobs].insert(
        job: "Spec::Job", outcome: "succeeded", duration: 1.0, query_count: 0, query_time: 0.0, occurred_at: at,
      )
    end

    before { stats(enqueued: 214) }

    it "says no worker is seen" do
      visit

      expect(health.find("h2")).to have_text(admin_t("ui.components.jobs.health.status.not_seen"))
    end

    it "says how long since the last job finished and how many jobs wait" do
      finish_job(Time.now - 2_286)
      finish_job(Time.now - 9_000)
      visit

      expect(page.find(".jobs-banner[role='alert']")).to have_text(warning(:last_job, ago: "38m"))
        .and have_text(warning(:waiting, count: 214, formatted: "214"))
    end

    it "says so when no job has finished" do
      visit

      expect(page.find(".jobs-banner")).to have_text(warning(:no_job))
    end
  end

  it "says the worker is quiet when nothing runs" do
    processes(process)
    visit

    expect(health.find("h2")).to have_text("Quiet")
  end

  it "says the worker is stopping when every process was told to stop" do
    processes(process(busy: 1, quiet: "true"))
    visit

    expect(health.find("h2")).to have_text("Stopping")
  end
end

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

  describe "running now" do
    def running = page.find(".card", text: admin_t("ui.components.jobs.running.title"))

    def work(identity, run_at, klass, *args)
      payload = { "class" => klass, "args" => args, "jid" => SecureRandom.hex(12), "queue" => "default" }
      hash = { "queue" => "default", "run_at" => run_at.to_i, "payload" => payload }

      [identity, SecureRandom.hex(4), Sidekiq::Work.new(identity, "tid", hash)]
    end

    def worker(identity, quiet: "false")
      Sidekiq::Process.new(
        "identity" => identity, "hostname" => "worker-#{identity}", "pid" => 4_120,
        "started_at" => (Time.now - 3_600).to_f, "queues" => %w[default mailers], "busy" => 1, "concurrency" => 5,
        "beat" => Time.now.to_f, "quiet" => quiet,
      )
    end

    describe "with a busy process and an idle one" do
      before do
        processes(worker("a"), worker("b"))
        allow(Sidekiq::WorkSet).to receive(:new)
          .and_return([work("a", Time.now - 252, "Posts::Jobs::RenderPost", 42)])
        visit
      end

      it "lists each process with its host, pid, busy of concurrency and queues" do
        expect(running).to have_css(".jobs-host", text: "worker-a · pid 4120")
          .and have_css(".jobs-capacity", exact_text: "1 of 5")
          .and have_css(".jobs-meta", text: "queues default, mailers")
      end

      it "lists each running job with its arguments and how long it has run" do
        expect(running).to have_css(".li-title", exact_text: "Posts::Jobs::RenderPost")
          .and have_css(".jobs-args", exact_text: "42")
          .and have_css(".jobs-ran.jobs-warn", exact_text: "4m")
      end

      it "says the idle process runs nothing" do
        expect(running.all(".jobs-process").last).to have_text(admin_t("ui.components.jobs.running.idle"))
      end
    end

    it "says a stopping process is finishing its jobs" do
      processes(worker("a", quiet: "true"))
      allow(Sidekiq::WorkSet).to receive(:new).and_return([work("a", Time.now - 5, "Posts::Jobs::RenderPost")])
      visit

      expect(running).to have_css(".jobs-stopping", exact_text: "finishing 1 job, taking no new work")
    end

    it "says no worker processes are running when there are none" do
      visit

      expect(running).to have_text(admin_t("ui.components.jobs.running.none"))
    end
  end

  describe "queues" do
    let(:queues) do
      [
        Spec::FakeQueue.new(name: "default", size: 250, latency: 700.0),
        Spec::FakeQueue.new(name: "mailers", size: 0, latency: 0.0),
      ]
    end

    def card = page.find("aside.card")

    def drawer = Capybara.string(last_response.body).find("dialog#jobs-queue")

    def queued(name, number, size)
      first = ((number - 1) * size) + 1
      last = [number * size, 250].min

      (first..last).map do |position|
        Sidekiq::JobRecord.new(
          { "class" => "Shares::Jobs::FetchTitle", "args" => [position], "jid" => "j#{position}",
            "enqueued_at" => (Time.now - 1_000 + position).to_f },
          name,
        )
      end
    end

    before do
      allow(Sidekiq::Queue).to receive(:all).and_return(queues)
      replace_component("sidekiq.queue_jobs", method(:queued))
    end

    it "lists each queue with its size and latency", :aggregate_failures do
      visit

      expect(card).to have_css(".li", count: 2)
      expect(card.find(".li", text: "default")).to have_css(".jobs-queue-size.jobs-bad", exact_text: "250")
        .and have_text("oldest waited 11m")
      expect(card.find(".li", text: "mailers")).to have_text("empty").and have_no_link("mailers")
    end

    it "opens a queue with jobs in a drawer, oldest first, 100 to a page", :aggregate_failures do
      visit
      get card.find_link("default")[:href]

      expect(drawer).to have_css(".jobs-waiting", exact_text: "250 waiting")
      expect(drawer.all(".jobs-args").map(&:text)).to eq((1..100).map(&:to_s))
      expect(drawer).to have_link(href: "/admin/settings/jobs?queue=default&page=2")
    end

    it "pages to later jobs" do
      get "/admin/settings/jobs?queue=default&page=3"

      expect(drawer.all(".jobs-args").map(&:text)).to eq((201..250).map(&:to_s))
    end

    it "labels the drawer's page links earlier and later, since the oldest job comes first" do
      get "/admin/settings/jobs?queue=default&page=2"

      expect(drawer.all(".pager-link").to_h { [it[:rel], [it.text.strip, it[:href]]] }).to eq(
        "prev" => ["earlier", "/admin/settings/jobs?queue=default"],
        "next" => ["later", "/admin/settings/jobs?queue=default&page=3"],
      )
    end

    it "opens no drawer for an empty queue" do
      get "/admin/settings/jobs?queue=mailers"

      expect(page).to have_no_css("dialog#jobs-queue")
    end

    it "opens no drawer for an unknown queue" do
      get "/admin/settings/jobs?queue=nope"

      expect(page).to have_no_css("dialog#jobs-queue")
    end
  end
end

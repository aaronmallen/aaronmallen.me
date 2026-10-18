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

  describe "one load" do
    let(:timing_queries) { Performance::Slice["repos.timing_queries"] }

    before do
      allow(timing_queries).to receive(:last_scheduled_runs).and_call_original
      replace_component("performance.repos.timing_queries", timing_queries)
      visit
    end

    it "reads the stats, the processes and the cron history once each", :aggregate_failures do
      expect(Sidekiq::Stats).to have_received(:new).once
      expect(Sidekiq::ProcessSet).to have_received(:new).once
      expect(timing_queries).to have_received(:last_scheduled_runs).once
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

    it "shows processed and failed today, said to be in UTC", :aggregate_failures do
      expect(page.find(".jobs-today")).to have_text("today (UTC)")
      expect(page.find(".jobs-big:not(.jobs-big-small)")).to have_text("1,240 processed")
      expect(page.find(".jobs-big.jobs-failed")).to have_text("3 failed")
    end

    it "draws a bar for each day, today last", :aggregate_failures do
      bars = page.all(".jobs-bar")

      expect(bars.size).to eq(7)
      expect(bars.last[:class]).to include("jobs-bar-today")
      expect(bars.last).to have_css("i.jobs-bar-failed")
    end

    it "names each day's figures in UTC for a screen reader", :aggregate_failures do
      label = page.find(".jobs-bars")["aria-label"]

      expect(label).to start_with("Processed and failed, last 7 days in UTC:")
      expect(label).to include("1,240 processed, 3 failed")
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

  describe "the cron schedule" do
    let(:schedule) { Hanami.app["sidekiq.schedule"] }

    def cron = page.find_by_id("jobs-cron")

    def entry(name) = cron.find("#jobs-cron-#{name}")

    def names = cron.all(".jobs-cron-name").map(&:text)

    def next_times(**times) = replace_component("sidekiq.schedule_times", -> { times.transform_keys(&:to_s) })

    def ran(name, outcome: "succeeded", at: Time.now - 60, duration: 1_500.0, **)
      job = schedule.fetch(name).fetch("class")
      schedule_key = Object.const_get(job).check_in_name(*schedule.fetch(name)["args"])

      Performance::Slice["db.rom"].relations[:performance_jobs].insert(
        job:, schedule_key:, outcome:, duration:, query_count: 0, query_time: 0.0, occurred_at: at, **,
      )
    end

    def states(**states)
      replace_component("sidekiq.schedule_states", -> { states.to_h { |name, state| [name.to_s, state.to_json] } })
    end

    before do
      next_times(publish_due_posts: (Time.now + 60).to_s)
      states
    end

    it "shows every entry with its description, cron string, class and args", :aggregate_failures do
      visit

      expect(names).to match_array(schedule.keys)
      expect(entry("sync_issues")).to have_text("every 15 minutes, from :06")
        .and have_css(".jobs-cron-code", exact_text: "6-59/15 * * * *")
        .and have_css(".jobs-cron-class", exact_text: 'Tasks::Jobs::SyncIssues ["github"]')
    end

    describe "with runs on record" do
      before do
        ran("publish_due_posts", at: Time.now - 60)
        ran("publish_due_posts", at: Time.now - 120, duration: 9_000.0)
        visit
      end

      it "shows the newest run's duration" do
        expect(entry("publish_due_posts")).to have_text("1.5 s")
      end

      it "shows the last and next run in Chicago time" do
        expect(entry("publish_due_posts").all("time").map { it["datetime"] })
          .to eq([Time.now - 60, Time.now + 60].map { Blog::TimeZone.local(it).iso8601 })
      end
    end

    it "says an entry with no run on record has none" do
      visit

      expect(entry("back_up_database")).to have_text(admin_t("ui.components.jobs.cron.never"))
    end

    it "shows a failed last run with its error, sorted first", :aggregate_failures do
      ran("back_up_database", outcome: "failed", error_class: "PG::Error", error_message: "disk full")
      visit

      expect(names.first).to eq("back_up_database")
      expect(entry("back_up_database")).to have_css(".pill", text: "failed")
        .and have_css(".jobs-cron-error", exact_text: "PG::Error disk full")
    end

    it "sorts the rest by next run" do
      next_times(sync_gmail: (Time.now + 30).to_s, publish_due_posts: (Time.now + 60).to_s)
      visit

      expect(names.first(2)).to eq(%w[sync_gmail publish_due_posts])
    end

    it "marks an entry more than five minutes overdue as missed", :aggregate_failures do
      next_times(sync_gmail: (Time.now - 301).to_s, publish_due_posts: (Time.now - 299).to_s)
      visit

      expect(entry("sync_gmail")).to have_css(".pill", text: "missed")
      expect(entry("publish_due_posts")).to have_no_css(".pill")
    end

    it "marks a paused entry" do
      states(sync_gmail: { enabled: false })
      visit

      expect(entry("sync_gmail")).to have_css(".pill", text: "paused")
        .and have_text(admin_t("ui.components.jobs.cron.paused_note"))
    end

    describe "with two entries of one class, one failed" do
      before do
        ran("sync_issues", outcome: "failed", error_class: "GitHub::Error", error_message: "rate limited")
        ran("sync_linear_issues")
        visit
      end

      it "reads each entry's own last run", :aggregate_failures do
        expect(entry("sync_issues")).to have_css(".pill", text: "failed")
        expect(entry("sync_linear_issues").all(".pill")).to be_empty
      end

      it "counts only the failed one on the jobs tab" do
        expect(jobs_tab).to eq("jobs 1")
      end
    end

    it "links an entry to its job's row in Performance, over a range that holds its last run" do
      ran("sync_gmail", at: Time.now - (10 * 86_400))
      visit

      expect(entry("sync_gmail")).to have_link(href: "/admin/performance?range=14#job-mail-jobs-syncgmail")
    end

    it "links an entry that never ran to no row" do
      visit

      expect(entry("sync_gmail").all("a")).to be_empty
    end

    describe "the filter" do
      it "counts every entry, the failed ones and the paused ones" do
        ran("back_up_database", outcome: "failed")
        states(sync_gmail: { enabled: false })
        visit

        expect(cron.all(".seg-option").map(&:text)).to eq(["all #{schedule.size}", "failed 1", "paused 1"])
      end

      it "narrows to failed entries" do
        ran("back_up_database", outcome: "failed")
        get "/admin/settings/jobs?cron=failed"

        expect(names).to eq(["back_up_database"])
      end

      it "narrows to paused entries" do
        states(sync_gmail: { enabled: false })
        get "/admin/settings/jobs?cron=paused"

        expect(names).to eq(["sync_gmail"])
      end

      it "says so when nothing failed" do
        get "/admin/settings/jobs?cron=failed"

        expect(cron.find(".empty")).to have_text(admin_t("ui.components.jobs.cron.empty.failed"))
      end

      it "says so when nothing is paused" do
        get "/admin/settings/jobs?cron=paused"

        expect(cron.find(".empty")).to have_text(admin_t("ui.components.jobs.cron.empty.paused"))
      end
    end

    it "adds failed cron entries to the jobs tab count" do
      stats(retry_size: 1, dead_size: 1)
      ran("back_up_database", outcome: "failed")
      visit

      expect(jobs_tab).to eq("jobs 3")
    end

    describe "with Redis down" do
      before do
        replace_component("sidekiq.schedule_times", -> { raise RedisClient::CannotConnectError, "refused" })
        visit
      end

      it "reads next run and paused as unknown", :aggregate_failures do
        expect(entry("sync_gmail")).to have_text(admin_t("ui.components.jobs.cron.unknown"))
        expect(cron.all(".seg-option").map(&:text).last).to eq("paused")
      end
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
        Sidekiq::Stats::QueueSummary.new(name: "mailers", size: 0, latency: 0.0, paused: false),
        Sidekiq::Stats::QueueSummary.new(name: "default", size: 250, latency: 700.0, paused: false),
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
      stats(queue_summaries: queues)
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

  describe "the job sets" do
    let(:sets) { %w[retry dead schedule].to_h { [it, Spec::FakeJobSet.new(it)] } }

    def card(name) = page.find_by_id("jobs-#{name}")

    def drawer = Capybara.string(last_response.body).find("dialog#jobs-job")

    def failed(klass, *args, error: "Faraday::TimeoutError", message: "execution expired", **)
      ms = ->(time) { (time.to_f * 1_000).to_i }

      {
        "class" => klass, "args" => args, "jid" => SecureRandom.hex(12), "queue" => "default",
        "created_at" => ms.call(Time.now - 600), "enqueued_at" => ms.call(Time.now - 600),
        "failed_at" => ms.call(Time.now - 300),
        "retry_count" => 2, "error_class" => error, "error_message" => message, **,
      }
    end

    def fill(name, at, item)
      sets.fetch(name).add(at, item)
      stats(retry_size: sets["retry"].size, dead_size: sets["dead"].size, scheduled_size: sets["schedule"].size)
      item
    end

    def set_page(key, number, size, reverse: false)
      entries = sets.fetch(key).to_a
      (reverse ? entries : entries.reverse).drop((number - 1) * size).first(size)
    end

    def titles(name) = card(name).all(".li-title").map(&:text)

    before do
      allow(Sidekiq::RetrySet).to receive(:new).and_return(sets["retry"])
      allow(Sidekiq::DeadSet).to receive(:new).and_return(sets["dead"])
      allow(Sidekiq::ScheduledSet).to receive(:new).and_return(sets["schedule"])
      replace_component("sidekiq.set_jobs", method(:set_page))
    end

    it "says so when each set is empty", :aggregate_failures do
      visit

      expect(card("retries")).to have_text(admin_t("ui.components.jobs.set.empty.retries"))
      expect(card("dead")).to have_text(admin_t("ui.components.jobs.set.empty.dead"))
      expect(card("scheduled")).to have_text(admin_t("ui.components.jobs.set.empty.scheduled"))
    end

    describe "with retries" do
      before do
        fill("retry", Time.now + 600, failed("Later::Job"))
        fill("retry", Time.now + 60, failed("Social::Jobs::CrossPost", 42, "mastodon"))
        visit
      end

      it "lists them soonest first" do
        expect(titles("retries")).to eq(%w[Social::Jobs::CrossPost Later::Job])
      end

      it "shows each one's arguments, error, retry count and next try" do
        expect(card("retries").first(".li")).to have_css(".jobs-args", exact_text: '42,"mastodon"')
          .and have_css(".jobs-error", exact_text: "Faraday::TimeoutError execution expired")
          .and have_css(".jobs-retrying", exact_text: "retries 2 of 25")
          .and have_css("time[datetime='#{Blog::TimeZone.local(Time.now + 60).iso8601}']")
      end
    end

    describe "with dead jobs" do
      before do
        fill("dead", Time.now - 600, failed("Older::Job", "retry_count" => 25))
        fill("dead", Time.now - 60, failed("Newer::Job", error: "PG::Error", message: "disk full", "retry_count" => 25))
        visit
      end

      it "lists them newest first" do
        expect(titles("dead")).to eq(%w[Newer::Job Older::Job])
      end

      it "shows each one's error and retry count" do
        expect(card("dead").first(".li")).to have_css(".jobs-error", exact_text: "PG::Error disk full")
          .and have_text("retries 25 of 25")
      end
    end

    it "lists scheduled jobs soonest first, with no error", :aggregate_failures do
      fill("schedule", Time.now + 600, { "class" => "Later::Job", "args" => [], "jid" => "b", "queue" => "default" })
      fill("schedule", Time.now + 60, { "class" => "Soon::Job", "args" => [1], "jid" => "a", "queue" => "default" })
      visit

      expect(titles("scheduled")).to eq(%w[Soon::Job Later::Job])
      expect(card("scheduled")).to have_no_css(".jobs-error")
    end

    describe "with more jobs than fit" do
      before { 120.times { fill("retry", Time.now + it, failed("Job#{it}")) } }

      it "shows five and links to the rest", :aggregate_failures do
        visit

        expect(titles("retries")).to eq((0..4).map { "Job#{it}" })
        expect(card("retries")).to have_link("Show all 120", href: "/admin/settings/jobs?set=retries#jobs-retries")
      end

      it "shows 100 to a page with page links that read sooner and later", :aggregate_failures do
        get "/admin/settings/jobs?set=retries"

        expect(titles("retries").size).to eq(100)
        expect(card("retries")).to have_link("later", href: "/admin/settings/jobs?set=retries&page=2#jobs-retries")
          .and have_link(admin_t("ui.components.jobs.set.fewer"), href: "/admin/settings/jobs#jobs-retries")
      end

      it "pages to later retries" do
        get "/admin/settings/jobs?set=retries&page=2"

        expect(titles("retries")).to eq((100..119).map { "Job#{it}" })
      end
    end

    it "labels dead pages newer and older, since the newest death comes first" do
      101.times { fill("dead", Time.now - it, failed("Job#{it}")) }
      get "/admin/settings/jobs?set=dead"

      expect(card("dead").find(".pager-link[rel='next']").text.strip).to eq("Older")
    end

    describe "the job drawer" do
      let(:backtrace) { ["app/jobs/cross_post.rb:31:in 'perform'", "sidekiq/processor.rb:220:in 'execute_job'"] }

      let!(:job) do
        compressed = [Zlib::Deflate.deflate(JSON.generate(backtrace))].pack("m0")
        item = failed("Social::Jobs::CrossPost", 42, { "thread" => true }, "error_backtrace" => compressed)
        fill("retry", Time.now + 60, item)
      end

      it "opens from a row" do
        visit
        get card("retries").find_link("Social::Jobs::CrossPost")[:href]

        expect(drawer).to have_css(".jobs-job-name", exact_text: "Social::Jobs::CrossPost")
      end

      it "shows the jid, queue, retry count and every time", :aggregate_failures do
        get "/admin/settings/jobs?open=retries&jid=#{job['jid']}"

        facts = drawer.all(".jobs-facts dt").map(&:text).zip(drawer.all(".jobs-facts dd").map(&:text)).to_h
        expect(facts).to include("jid" => job["jid"], "queue" => "default", "retries" => "2 of 25")
        expect(facts.keys).to include("created", "enqueued", "failed", "next try")
      end

      it "counts retries against Sidekiq's configured most for a job with no retry count of its own" do
        allow(Sidekiq.default_configuration).to receive(:[]).and_call_original
        allow(Sidekiq.default_configuration).to receive(:[]).with(:max_retries).and_return(5)

        get "/admin/settings/jobs?open=retries&jid=#{job['jid']}"

        expect(drawer.find(".jobs-facts")).to have_text("2 of 5")
      end

      it "shows the error, the arguments in full and the backtrace", :aggregate_failures do
        get "/admin/settings/jobs?open=retries&jid=#{job['jid']}"

        expect(drawer).to have_css(".jobs-error", exact_text: "Faraday::TimeoutError execution expired")
        expect(drawer.first(".jobs-pre").text).to eq(JSON.pretty_generate([42, { "thread" => true }]))
        expect(drawer.find(".jobs-backtrace")).to have_text("2 lines").and have_text(backtrace.last)
      end

      it "opens no drawer for an unknown job" do
        get "/admin/settings/jobs?open=dead&jid=#{job['jid']}"

        expect(page).to have_no_css("dialog#jobs-job")
      end
    end
  end
end

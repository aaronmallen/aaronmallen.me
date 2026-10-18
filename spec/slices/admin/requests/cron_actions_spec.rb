# frozen_string_literal: true

RSpec.describe "Admin cron entry actions", :frozen_clock, type: :request do
  let(:store) { {} }

  def entry(name) = page.find("#jobs-cron-#{name}")

  def menu(name) = get("/admin/settings/jobs/cron/#{name}/menu", return_to: "/admin/settings/jobs?cron=paused")

  def ran_gmail
    Performance::Slice["db.rom"].relations[:performance_jobs].insert(
      job: "Mail::Jobs::SyncGmail", schedule_key: Mail::Jobs::SyncGmail.check_in_name, outcome: "succeeded",
      duration: 10.0, query_count: 0, query_time: 0.0, occurred_at: Time.now - 60,
    )
  end

  def redis_down = replace_component("sidekiq.schedule_states", -> { raise RedisClient::CannotConnectError, "refused" })

  before do
    sign_in_to_admin
    allow(SidekiqScheduler::RedisManager).to receive(:set_job_state) { |name, state| store[name] = state.to_json }
    replace_component("sidekiq.schedule_states", -> { store })
    replace_component("sidekiq.schedule_times", -> { {} })
  end

  describe "run now" do
    it "enqueues the entry's class with its args, never to retry", :aggregate_failures do
      admin_post "/admin/settings/jobs/cron/sync_issues/run"

      expect(Tasks::Jobs::SyncIssues.jobs.map { it.values_at("args", "retry") }).to eq([[["github"], false]])
      expect(toast).to eq("Queued to run now")
    end

    it "lands back on the cron section" do
      admin_post "/admin/settings/jobs/cron/sync_issues/run", return_to: "/admin/settings/jobs?cron=failed"

      expect(last_response.location).to end_with("/admin/settings/jobs?cron=failed#jobs-cron")
    end

    it "answers 404 for an entry the schedule lacks" do
      admin_post "/admin/settings/jobs/cron/nothing/run"

      expect(last_response.status).to eq(404)
    end

    it "says so when the queue is down" do
      allow(Tasks::Jobs::SyncIssues).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)
      admin_post "/admin/settings/jobs/cron/sync_issues/run"

      expect(toast).to eq(admin_t("queue_unavailable"))
    end
  end

  describe "pause and enable" do
    it "pauses an entry through the scheduler's own enabled state", :aggregate_failures do
      admin_post "/admin/settings/jobs/cron/sync_gmail/pause"

      expect(JSON.parse(store.fetch("sync_gmail"))).to eq("enabled" => false)
      expect(toast).to start_with("Paused")
      expect(entry("sync_gmail")).to have_css(".pill", text: "paused")
        .and have_button("Enable sync_gmail")
    end

    it "enables a paused entry", :aggregate_failures do
      store["sync_gmail"] = { enabled: false }.to_json
      admin_post "/admin/settings/jobs/cron/sync_gmail/enable"

      expect(JSON.parse(store.fetch("sync_gmail"))).to eq("enabled" => true)
      expect(toast).to start_with("Enabled")
      expect(entry("sync_gmail")).to have_no_css(".pill").and have_button("Pause sync_gmail")
    end

    it "answers 404 for an entry the schedule lacks" do
      admin_post "/admin/settings/jobs/cron/nothing/pause"

      expect(last_response.status).to eq(404)
    end

    it "changes nothing and says so when Redis is down" do
      allow(SidekiqScheduler::RedisManager).to receive(:set_job_state).and_raise(RedisClient::CannotConnectError)
      admin_post "/admin/settings/jobs/cron/sync_gmail/pause"

      expect(toast).to start_with("Nothing changed")
    end
  end

  describe "the row" do
    it "carries its menu and buttons to run and pause", :aggregate_failures do
      get "/admin/settings/jobs"

      expect(entry("sync_gmail")["data-menu"]).to eq("/admin/settings/jobs/cron/sync_gmail/menu")
      expect(entry("sync_gmail")).to have_button("Run sync_gmail now").and have_button("Pause sync_gmail")
    end

    it "lands a button back on the filtered view it was pressed on", :aggregate_failures do
      store["sync_gmail"] = { enabled: false }.to_json
      get "/admin/settings/jobs?cron=paused"
      form = entry("sync_gmail").find("form[action='/admin/settings/jobs/cron/sync_gmail/enable']")
      admin_post form[:action], return_to: form.find("input[name=return_to]", visible: :all).value

      expect(last_response.location).to end_with("/admin/settings/jobs?cron=paused#jobs-cron")
    end

    it "sends a button on the unfiltered view back to it" do
      get "/admin/settings/jobs"

      expect(entry("sync_gmail").all("input[name=return_to]", visible: :all).map(&:value).uniq)
        .to eq(["/admin/settings/jobs"])
    end

    it "drops the buttons when Redis is down" do
      redis_down
      get "/admin/settings/jobs"

      expect(entry("sync_gmail")).to have_no_button
    end
  end

  describe "the menu" do
    it "runs, pauses and opens the entry in Performance", :aggregate_failures do
      ran_gmail
      menu("sync_gmail")

      expect(menu_items).to eq(["Run now", "Pause", "Open in Performance"])
      expect(page).to have_link(href: "/admin/performance?range=7#job-mail-jobs-syncgmail")
    end

    it "brings each action back to the page it opened on" do
      menu("sync_gmail")

      expect(page.all("input[name=return_to]",
                      visible: :all).map(&:value).uniq).to eq(["/admin/settings/jobs?cron=paused"])
    end

    it "offers Enable on a paused entry and no Performance link with no run on record" do
      store["sync_gmail"] = { enabled: false }.to_json
      menu("sync_gmail")

      expect(menu_items).to eq(["Run now", "Enable"])
    end

    it "turns the actions off when Redis is down" do
      redis_down
      menu("sync_gmail")

      expect(page.all("[data-context-menu] button", visible: :all).map { it[:disabled] }).to all(be_truthy)
    end

    it "answers 404 for an entry the schedule lacks" do
      menu("nothing")

      expect(last_response.status).to eq(404)
    end
  end
end

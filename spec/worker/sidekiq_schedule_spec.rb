# frozen_string_literal: true

require "fugit"

RSpec.describe "The worker's schedule", type: :app do
  let(:config) { sidekiq_config }
  let(:schedule) { config.dig(:scheduler, :schedule) }

  def cron(name) = Fugit::Cron.parse(schedule.fetch(name).fetch("cron"))

  it "names a scheduled job that exists in every entry" do
    classes = schedule.values.map { it.fetch("class") }

    expect(classes).to all(satisfy { Object.const_defined?(it) && Object.const_get(it) < Blog::ScheduledJob })
  end

  it "never retries a scheduled job, since its next run tries again" do
    retries = schedule.values.map { Object.const_get(it.fetch("class")).get_sidekiq_options["retry"] }

    expect(retries).to all(be(false))
  end

  it "names a Honeybadger check-in setting for every entry" do
    store = Hanami::Settings::FileStore.new(File.expand_path("../../config/settings/default.yml", __dir__))
    names = schedule.values.map { Object.const_get(it.fetch("class")).check_in_name(*it["args"]) }

    expect(store.fetch("honeybadger").fetch("check_ins").keys).to match_array(names)
  end

  it "puts every job on a queue the worker reads", :aggregate_failures do
    queues = jobs.to_h { [it.name, it.get_sidekiq_options["queue"]] }

    expect(queues).not_to be_empty
    expect(queues).to all(satisfy { |_job, queue| config[:queues].include?(queue) })
  end

  def jobs
    Hanami.app.slices.to_a.flat_map do |slice|
      Dir[slice.root.join("jobs", "*.rb")].map do |path|
        slice.namespace.const_get(slice.inflector.camelize("jobs/#{File.basename(path, '.rb')}"))
      end
    end
  end

  def quarter_hourly = schedule.keys.select { cron(it).rough_frequency == 15 * 60 }

  it "gives each fifteen minute job a minute of its own" do
    minutes = quarter_hourly.flat_map { cron(it).minutes }

    expect(minutes).to eq(minutes.uniq)
  end

  it "keeps Gmail out of the minutes the fifteen minute jobs run in" do
    expect(cron("sync_gmail").minutes & quarter_hourly.flat_map { cron(it).minutes }).to be_empty
  end

  describe "the sprint roll-over" do
    let(:entry) { schedule.fetch("roll_over_sprint") }
    let(:cron) { Fugit::Cron.parse(entry.fetch("cron")) }
    let(:run) { cron.next_time(Time.utc(2026, 9, 17, 12)) }

    it "runs once a day, as the Chicago day turns, not the UTC one", :aggregate_failures do
      expect(Blog::TimeZone.local(run.to_t).iso8601).to eq("2026-09-18T00:00:00-05:00")
      expect(cron.next_time(run).to_t - run.to_t).to eq(24 * 60 * 60)
    end
  end

  describe "the post link check" do
    let(:cron) { Fugit::Cron.parse(schedule.fetch("check_post_links").fetch("cron")) }
    let(:run) { cron.next_time(Time.utc(2026, 9, 17, 12)) }

    it "runs every night at 03:00 Chicago", :aggregate_failures do
      expect(Blog::TimeZone.local(run.to_t).iso8601).to eq("2026-09-18T03:00:00-05:00")
      expect(cron.next_time(run).to_t - run.to_t).to eq(24 * 60 * 60)
    end
  end
end

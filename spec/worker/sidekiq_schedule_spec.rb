# frozen_string_literal: true

require "fugit"

RSpec.describe "The worker's schedule", type: :app do
  let(:config) { sidekiq_config }
  let(:schedule) { config.dig(:scheduler, :schedule) }

  def jobs
    Hanami.app.slices.to_a.flat_map do |slice|
      Dir[slice.root.join("jobs", "*.rb")].map do |path|
        slice.namespace.const_get(slice.inflector.camelize("jobs/#{File.basename(path, '.rb')}"))
      end
    end
  end

  it "names a scheduled job that exists in every entry" do
    classes = schedule.values.map { it.fetch("class") }

    expect(classes).to all(satisfy { Object.const_defined?(it) && Object.const_get(it) < Blog::ScheduledJob })
  end

  it "never retries a scheduled job, since its next run tries again" do
    retries = schedule.values.map { Object.const_get(it.fetch("class")).get_sidekiq_options["retry"] }

    expect(retries).to all(be(false))
  end

  it "puts every job on a queue the worker reads", :aggregate_failures do
    queues = jobs.to_h { [it.name, it.get_sidekiq_options["queue"]] }

    expect(queues).not_to be_empty
    expect(queues).to all(satisfy { |_job, queue| config[:queues].include?(queue) })
  end

  describe "the pull request import" do
    let(:cron) { Fugit::Cron.parse(schedule.fetch("import_pull_requests").fetch("cron")) }

    it "runs every 15 minutes" do
      run = cron.next_time(Time.utc(2026, 9, 17, 12))

      expect(cron.next_time(run).to_t - run.to_t).to eq(15 * 60)
    end
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
end

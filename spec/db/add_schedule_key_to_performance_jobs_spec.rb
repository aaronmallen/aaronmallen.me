# frozen_string_literal: true

RSpec.describe "Adding a schedule key to performance jobs", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:schedule) { sidekiq_config.dig(:scheduler, :schedule) }
  let(:migration) do
    path = Hanami.app.root.join("config/db/migrate/20261017230003_add_schedule_key_to_performance_jobs.rb")
    ROM::SQL.with_gateway(Hanami.app["db.rom"].gateways[:default]) { load path.to_s }
    Sequel::Migration.descendants.last
  end

  def job(name)
    db[:performance_jobs].insert(job: name, outcome: "succeeded", duration: 1, query_count: 0, query_time: 0)
  end

  def keys = db[:performance_jobs].exclude(schedule_key: nil).select_map(%i[job schedule_key])

  before do
    migration.apply(db, :down)
    [*schedule.values.map { it.fetch("class") }.uniq, "Posts::Jobs::Unscheduled"].each { job(it) }
    migration.apply(db, :up)
  end

  it "keys each run of a class one schedule entry runs by that entry's check-in name" do
    single = schedule.values.group_by { it.fetch("class") }.filter_map do |name, (entry, *rest)|
      [name, Object.const_get(name).check_in_name(*entry["args"])] if rest.empty?
    end

    expect([keys.empty?, keys - single]).to eq([false, []])
  end

  it "leaves a job the schedule does not run without a key" do
    expect(db[:performance_jobs].where(job: "Posts::Jobs::Unscheduled").get(:schedule_key)).to be_nil
  end
end

# frozen_string_literal: true

RSpec.describe Blog::ScheduledJob do
  let(:events) { [] }
  let!(:finished) { stub_request(:get, "https://api.honeybadger.io/v1/check_in/abc123").to_return { (events << :checked_in) && {} } }
  let!(:raised) { stub_request(:get, "https://api.honeybadger.io/v1/check_in/def456") }
  let!(:synced) { stub_request(:get, "https://api.honeybadger.io/v1/check_in/ghi789") }

  def job(name, &) = stub_const("Spec::#{name}", Class.new(described_class, &))

  before do
    check_ins = { "finished_job" => "abc123", "raising_job" => "def456", "sync_job_linear" => "ghi789" }
    store = Hanami::Settings::CompositeStore.new({ honeybadger: { check_ins: } }, Hanami.app.config.settings_store)
    replace_component("settings", Blog::Settings.new(store))
    replace_component("honeybadger.agent", Honeybadger::Agent.new(api_key: "spec-key", backend: "server"))
    connection = pool
    Sidekiq::Testing.server_middleware do |chain|
      chain.add Blog::JobCheckIn
      chain.add Blog::JobConnection, -> { connection }
      chain.add Blog::JobTimer, ->(**) { events << :timed }
    end
  end

  after do
    Sidekiq::Testing.server_middleware { |chain| [Blog::JobCheckIn, Blog::JobConnection, Blog::JobTimer].each { chain.remove it } }
  end

  def pool
    log = events
    Object.new.tap { it.define_singleton_method(:synchronize) { |&run| run.call.tap { log << :released } } }
  end

  def run(job, *)
    job.perform_async(*)
    job.drain
  end

  it "checks in with Honeybadger after a run that finishes" do
    run(job("FinishedJob") { def perform = :done })

    expect(finished).to have_been_requested.once
  end

  it "checks in once the timer has stopped and the connection is back in the pool" do
    run(job("FinishedJob") { def perform = :done })

    expect(events).to eq(%i[timed released checked_in])
  end

  it "sends no check-in after a run that raises", :aggregate_failures do
    expect { run(job("RaisingJob") { def perform = raise("boom") }) }.to raise_error("boom")
    expect(raised).not_to have_been_requested
  end

  it "checks in under the job's name and its arguments" do
    run(job("SyncJob") { def perform(_provider) = nil }, "linear")

    expect(synced).to have_been_requested.once
  end

  it "runs a job with no check-in set up and sends nothing", :aggregate_failures do
    ran = []
    run(job("QuietJob") { define_method(:perform) { ran << :ran } })

    expect(ran).to eq([:ran])
    expect(a_request(:get, %r{/v1/check_in/})).not_to have_been_made
  end
end

# frozen_string_literal: true

RSpec.describe Blog::ScheduledJob do
  let(:agent) { Honeybadger::Agent.new(api_key: "spec-key", backend: "server") }
  let(:check_ins) { { "finished_job" => "abc123", "raising_job" => "def456", "sync_job_linear" => "ghi789" } }
  let!(:finished) { stub_request(:get, "https://api.honeybadger.io/v1/check_in/abc123") }
  let!(:raised) { stub_request(:get, "https://api.honeybadger.io/v1/check_in/def456") }
  let!(:synced) { stub_request(:get, "https://api.honeybadger.io/v1/check_in/ghi789") }

  before do
    store = Hanami::Settings::CompositeStore.new({ honeybadger: { check_ins: } }, Hanami.app.config.settings_store)
    replace_component("settings", Blog::Settings.new(store))
    replace_component("honeybadger.agent", agent)
  end

  def job(name, &) = stub_const("Spec::#{name}", Class.new(described_class, &)).new

  it "checks in with Honeybadger after a run that finishes" do
    job("FinishedJob") { def perform = :done }.perform

    expect(finished).to have_been_requested.once
  end

  it "returns what the run returned" do
    expect(job("FinishedJob") { def perform = :done }.perform).to eq(:done)
  end

  it "sends no check-in after a run that raises", :aggregate_failures do
    expect { job("RaisingJob") { def perform = raise("boom") }.perform }.to raise_error("boom")
    expect(raised).not_to have_been_requested
  end

  it "checks in under the job's name and its arguments" do
    job("SyncJob") { def perform(_provider) = nil }.perform("linear")

    expect(synced).to have_been_requested.once
  end

  it "runs a job with no check-in set up and sends nothing", :aggregate_failures do
    expect(job("QuietJob") { def perform = :done }.perform).to eq(:done)
    expect(a_request(:get, %r{/v1/check_in/})).not_to have_been_made
  end
end

# frozen_string_literal: true

require "sidekiq/scheduled"

RSpec.describe "Redis dropping under the worker", type: :app do
  let(:agent) { Hanami.app["honeybadger.agent"] }
  let(:notices) { [] }
  let(:poller) { Sidekiq::Scheduled::Poller.new(sidekiq) }

  let(:sidekiq) do
    Sidekiq::Config.new.tap do |config|
      config.logger = Logger.new(File::NULL)
      config.redis = { url: "redis://127.0.0.1:1", connect_timeout: 0.1, reconnect_attempts: 0 }
      config.error_handlers.replace([->(error, context, _config) { agent.notify(error, parameters: context) }])
    end
  end

  def run_on(name, &) = poller.safe_thread(name, &).join

  before do
    record = ->(build, *args) { build.call(*args).tap { notices << it } }
    allow(Honeybadger::Notice).to receive(:new).and_wrap_original(&record)
  end

  after { poller.terminate }

  context "when the scheduler cannot reach Redis" do
    before { run_on("scheduler") { poller.enqueue } }

    it "builds the notice" do
      expect(notices.map(&:exception)).to contain_exactly(an_instance_of(RedisClient::CannotConnectError))
    end

    it "sends Honeybadger nothing" do
      expect(notices).to all(be_halted)
    end
  end

  context "when the scheduler raises something else" do
    let(:crash) { RuntimeError.new("boom") }

    before do
      allow(sidekiq).to receive(:redis).and_raise(crash)
      run_on("scheduler") { poller.enqueue }
    end

    it "tells Honeybadger" do
      expect(notices).to contain_exactly(have_attributes(exception: crash, halted?: false))
    end
  end

  context "when a job cannot reach Redis" do
    let(:error) { RedisClient::CannotConnectError.new("down") }

    before { run_on("processor") { agent.notify(error) } }

    it "tells Honeybadger" do
      expect(notices).to contain_exactly(have_attributes(exception: error, halted?: false))
    end
  end
end

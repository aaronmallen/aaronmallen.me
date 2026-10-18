# frozen_string_literal: true

require "sidekiq"

Sidekiq.testing!(:fake)
Hanami.app.start(:sidekiq)
Sidekiq.default_configuration.logger.level = Logger::WARN

module Spec
  class FakeJobSet
    include Enumerable

    attr_reader :name

    def initialize(name)
      @entries = []
      @name = name
    end

    def add(at, item) = @entries << Sidekiq::SortedEntry.new(self, at.to_f, Sidekiq.dump_json(item))

    def delete_by_value(_name, value) = @entries.delete_if { it.value == value }

    def each(&) = @entries.sort_by { -it.score }.each(&)

    def find_job(jid) = find { it.jid == jid }

    def kill(message) = add(Time.now, Sidekiq.load_json(message))

    def remove_job(entry)
      yield entry.value if @entries.reject! { it.value == entry.value }
    end

    def size = @entries.size
  end

  class FakeHistory
    attr_reader :failed, :processed

    def initialize(days = {})
      today = Time.now.utc.to_date
      dates = today.downto(today - 6).map(&:to_s)
      @processed = dates.to_h { [it, days.dig(Date.parse(it), :processed) || 0] }
      @failed = dates.to_h { [it, days.dig(Date.parse(it), :failed) || 0] }
    end
  end

  FakeStats = Data.define(:enqueued, :scheduled_size, :retry_size, :dead_size, :queue_summaries) do
    def initialize(enqueued: 0, scheduled_size: 0, retry_size: 0, dead_size: 0, queue_summaries: []) = super
  end

  module SyncStates
    def sync_state_mutations = Record::Slice["repos.sync_state_mutations"]

    def sync_state_queries = Record::Slice["repos.sync_state_queries"]
  end

  module SidekiqConfig
    def sidekiq_config(environment = :development)
      config = Blog::SidekiqConfig.load

      config.merge(config.delete(environment.to_sym) || {})
    end
  end
end

RSpec.configure do |config|
  config.before do
    Sidekiq::Job.clear_all
    allow(Sidekiq::ProcessSet).to receive(:new).and_return([])
    allow(Sidekiq::Stats).to receive(:new).and_return(Spec::FakeStats.new)
    allow(Sidekiq::Stats::History).to receive(:new).and_return(Spec::FakeHistory.new)
    allow(Sidekiq::WorkSet).to receive(:new).and_return([])
  end
  config.include Spec::SidekiqConfig
  config.include Spec::SyncStates
end

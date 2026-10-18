# frozen_string_literal: true

require "sidekiq"

Sidekiq.testing!(:fake)
Hanami.app.start(:sidekiq)
Sidekiq.default_configuration.logger.level = Logger::WARN

module Spec
  class RedisRefused < RedisClient::CannotConnectError; end

  module RefuseRedis
    def self.check!(example)
      refused = @refused
      @refused = nil
      return if refused.nil? || refused.equal?(example.exception) || example.metadata[:redis_outage]

      raise RedisRefused, "#{example.location} reached Redis and went on past the refusal, so it tests the Redis " \
                          "outage path: stub the Sidekiq call, or tag the spec redis_outage: true"
    end

    def self.refuse!(message) = raise(@refused = RedisRefused.new(message))

    def connect(_config)
      example = RSpec.current_example&.location || "a spec outside an example"
      RefuseRedis.refuse!("#{example} opened a Redis connection, which fails in CI: " \
                          "stub the Sidekiq call or replace the sidekiq.* component")
    end
  end

  RedisClient.register(RefuseRedis)

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
    allow(Sidekiq::DeadSet).to receive(:new).and_return(Spec::FakeJobSet.new("dead"))
    allow(Sidekiq::RetrySet).to receive(:new).and_return(Spec::FakeJobSet.new("retry"))
    allow(Sidekiq::ScheduledSet).to receive(:new).and_return(Spec::FakeJobSet.new("schedule"))
    allow(Blog::SidekiqSetPage).to receive(:call).and_return([])
    allow(Blog::SidekiqQueuePage).to receive(:call).and_return([])
    replace_component("sidekiq.schedule_states", -> { {} })
    replace_component("sidekiq.schedule_times", -> { {} })
  end
  config.after { |example| Spec::RefuseRedis.check!(example) }
  config.include Spec::SidekiqConfig
  config.include Spec::SyncStates
end

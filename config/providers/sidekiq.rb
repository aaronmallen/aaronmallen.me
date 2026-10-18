# frozen_string_literal: true

Hanami.app.register_provider :sidekiq do
  prepare do
    require "sidekiq"
    require "sidekiq/api"
    require "sidekiq-scheduler"
  end

  start do
    redis = target["settings"].redis.compact

    Sidekiq.configure_client { it.redis = redis }
    Sidekiq.configure_server { it.redis = redis }

    register("sidekiq.dead_set") { -> { Sidekiq::DeadSet.new } }
    register("sidekiq.processes") { -> { Sidekiq::ProcessSet.new } }
    register("sidekiq.queues") { -> { Sidekiq::Queue.all } }
    register("sidekiq.retry_set") { -> { Sidekiq::RetrySet.new } }
    register("sidekiq.scheduled_set") { -> { Sidekiq::ScheduledSet.new } }
    register("sidekiq.stats") { -> { Sidekiq::Stats.new } }
    register("sidekiq.stats_history") { ->(days) { Sidekiq::Stats::History.new(days) } }
    register("sidekiq.work") { -> { Sidekiq::WorkSet.new } }
  end
end

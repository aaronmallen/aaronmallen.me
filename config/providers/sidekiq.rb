# frozen_string_literal: true

Hanami.app.register_provider :sidekiq do
  prepare do
    require "sidekiq"
    require "sidekiq/api"
    require "sidekiq-scheduler"
  end

  start do
    hash = ->(key) { Sidekiq.redis { it.hgetall(key) } }
    redis = target["settings"].redis.compact

    Sidekiq.configure_client { it.redis = redis }
    Sidekiq.configure_server { it.redis = redis }

    register("sidekiq.dead_set") { -> { Sidekiq::DeadSet.new } }
    register("sidekiq.processes") { -> { Sidekiq::ProcessSet.new } }
    register("sidekiq.queue_jobs") { Blog::SidekiqQueuePage }
    register("sidekiq.retry_set") { -> { Sidekiq::RetrySet.new } }
    register("sidekiq.scheduled_set") { -> { Sidekiq::ScheduledSet.new } }
    register("sidekiq.set_jobs") { Blog::SidekiqSetPage }
    register("sidekiq.schedule", Blog::SidekiqConfig.load.dig(:scheduler, :schedule).freeze)
    register("sidekiq.schedule_state") { ->(name, state) { SidekiqScheduler::RedisManager.set_job_state(name, state) } }
    register("sidekiq.schedule_states") { -> { hash.call(SidekiqScheduler::RedisManager.schedules_state_key) } }
    register("sidekiq.schedule_times") { -> { hash.call(SidekiqScheduler::RedisManager.next_times_key) } }
    register("sidekiq.stats") { -> { Sidekiq::Stats.new } }
    register("sidekiq.stats_history") { ->(days) { Sidekiq::Stats::History.new(days) } }
    register("sidekiq.work") { -> { Sidekiq::WorkSet.new } }
  end
end

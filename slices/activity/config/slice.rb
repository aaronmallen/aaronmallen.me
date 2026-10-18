# frozen_string_literal: true

module Activity
  class Slice < Hanami::Slice
    config.shared_app_component_keys += %w[
      sidekiq.dead_set sidekiq.processes sidekiq.queue_jobs sidekiq.queues sidekiq.retry_set sidekiq.scheduled_set
      sidekiq.stats sidekiq.stats_history sidekiq.work
    ]

    import keys: %w[repos.analytics_rollup_queries], from: :analytics
    import keys: %w[repos.timing_queries], from: :performance

    export %w[
      operations.discard_dead_job operations.retry_dead_job operations.snooze_attention repos.activity_queries
      repos.attention_queries repos.job_queries repos.review_queries
    ]
  end
end

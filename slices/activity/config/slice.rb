# frozen_string_literal: true

module Activity
  class Slice < Hanami::Slice
    config.shared_app_component_keys += %w[
      sidekiq.dead_set sidekiq.processes sidekiq.queue_jobs sidekiq.retry_set sidekiq.schedule sidekiq.schedule_state
      sidekiq.schedule_states sidekiq.schedule_times sidekiq.scheduled_set sidekiq.set_jobs sidekiq.stats
      sidekiq.stats_history sidekiq.work
    ]

    import keys: %w[repos.analytics_rollup_queries], from: :analytics
    import keys: %w[repos.timing_queries], from: :performance

    export %w[
      operations.act_on_set_job operations.run_cron_entry operations.snooze_attention
      operations.switch_cron_entry repos.activity_queries repos.attention_queries repos.cron_queries repos.job_queries
      repos.review_queries
    ]
  end
end

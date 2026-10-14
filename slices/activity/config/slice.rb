# frozen_string_literal: true

module Activity
  class Slice < Hanami::Slice
    config.shared_app_component_keys += %w[sidekiq.dead_set]

    import keys: %w[repos.analytics_rollup_queries], from: :analytics

    export %w[
      operations.discard_dead_job operations.retry_dead_job operations.snooze_attention repos.activity_queries
      repos.attention_queries repos.review_queries
    ]
  end
end

# frozen_string_literal: true

module Analytics
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/analytics"), namespace: Analytics)

    config.shared_app_component_keys += %w[http]

    import keys: %w[operations.record_country_sync_outcome operations.record_rollup_sync_outcome], from: :record

    export %w[
      contracts.visit_contract operations.hash_visitor operations.record_feed_fetch operations.record_visit
      repos.analytics_event_queries repos.analytics_page_queries repos.analytics_rollup_queries repos.country_queries
      repos.feed_fetch_queries repos.post_reader_queries
    ]
  end
end

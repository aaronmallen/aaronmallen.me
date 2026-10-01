# frozen_string_literal: true

module Analytics
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/analytics"), namespace: Analytics)

    config.shared_app_component_keys += %w[http]

    import keys: %w[operations.record_country_sync_outcome operations.record_rollup_sync_outcome], from: :record

    export %w[
      contracts.visit_contract operations.hash_visitor operations.record_visit queries.country_counts
      queries.country_database_failure queries.devices_between queries.hourly_between queries.navigation_between
      queries.page_between queries.reach_between queries.read_spread_between queries.referrer_counts
      queries.rollups_between queries.scroll_depths_between queries.sources_between queries.summary_between
      queries.top_paths queries.unrolled_summaries queries.view_totals queries.views_by_path queries.views_by_post
      queries.visitors_for_day
    ]
  end
end

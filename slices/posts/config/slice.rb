# frozen_string_literal: true

module Posts
  class Slice < Hanami::Slice
    config.no_auto_register_paths += %w[helpers]

    config.shared_app_component_keys += %w[honeybadger.agent]

    import keys: %w[repos.analytics_rollup_queries repos.post_reader_queries], from: :analytics

    import keys: %w[operations.claim_photos operations.release_photos], from: :media

    import keys: %w[
      operations.check_network_fit operations.resolve_mentions repos.webmention_queries
    ], from: :social

    import keys: %w[operations.check_short_links], from: :shares

    export %w[
      operations.act_on_posts operations.check_post_links operations.compose_announcement operations.delete_post
      operations.lock_unpublished_post operations.move_post operations.publish_draft operations.queue_link_check
      operations.record_post_webmentions operations.revise_edit_note operations.revise_post_body operations.save_post
      operations.save_post_seo repos.post_figure_queries repos.post_queries
    ]
  end
end

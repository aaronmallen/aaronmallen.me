# frozen_string_literal: true

module Social
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/social"), namespace: Social)

    config.shared_app_component_keys += %w[http]

    import keys: %w[
      operations.compose_announcement operations.record_post_webmentions queries.by_id queries.published_by_slug
    ], from: :posts

    export %w[
      networks.all operations.compose_social_post operations.delete_person operations.delete_social_post
      operations.lock_editable_social_post operations.moderate_webmention operations.receive_webmention
      operations.replace_social_post_parts operations.save_person operations.save_social_post
      operations.update_webmention_settings queries.counted_webmentions_for_post queries.editable_social_post
      queries.listed_webmentions_for_post queries.mention_directory queries.pending_webmention_count
      queries.pending_webmentions queries.people queries.person_by_id queries.queued_social_posts
      queries.received_webmention_count
      queries.social_post_by_id queries.social_post_counts_by_status queries.social_posts_by_filter
      queries.social_posts_dated_between queries.syndication_urls queries.unsent_social_posts
      queries.webmention_counts_by_post queries.webmention_counts_by_status queries.webmention_settings
      queries.webmentions_by_status queries.webmentions_received_between queries.webmentions_received_by_post
      queries.webmentions_received_in
    ]
  end
end

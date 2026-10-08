# frozen_string_literal: true

module Social
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/social"), namespace: Social)

    config.shared_app_component_keys += %w[honeybadger.agent http]

    import keys: %w[operations.tag_ref], from: :analytics

    import keys: %w[
      operations.compose_announcement operations.record_post_webmentions repos.post_queries
    ], from: :posts

    export %w[
      networks.all operations.act_on_webmentions operations.compose_social_post operations.delete_person
      operations.delete_social_post operations.expand_for_network operations.lock_editable_social_post
      operations.mark_webmention_seen operations.measure_parts operations.moderate_webmention
      operations.move_social_post operations.receive_webmention operations.replace_social_post_parts
      operations.resolve_mentions operations.save_person operations.save_social_post operations.search_accounts
      operations.snooze_webmentions operations.update_webmention_settings operations.wake_webmention
      repos.person_queries repos.social_post_queries repos.webmention_queries
    ]
  end
end

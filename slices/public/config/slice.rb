# frozen_string_literal: true

module Public
  class Slice < Hanami::Slice
    config.no_auto_register_paths += %w[helpers]

    config.shared_app_component_keys += %w[assets]

    config.actions.default_headers["Vary"] = "Cookie"

    import keys: %w[auth.session_reader], from: :admin

    import keys: %w[
      operations.check_visit operations.hash_visitor operations.record_feed_fetch operations.record_visit
      operations.tag_ref
    ], from: :analytics

    import keys: %w[operations.create_message], from: :mail

    import keys: %w[repos.photo_queries], from: :media

    import keys: %w[operations.record_page_timing], from: :performance

    import keys: %w[repos.project_queries repos.work_entry_queries], from: :projects

    import keys: %w[repos.post_queries], from: :posts

    import keys: %w[operations.claim_search_attempt repos.public_search_queries], from: :search

    import keys: %w[repos.task_comment_queries repos.task_queries], from: :tasks

    import keys: %w[operations.receive_webmention repos.social_post_queries repos.webmention_queries], from: :social

    export []
  end
end

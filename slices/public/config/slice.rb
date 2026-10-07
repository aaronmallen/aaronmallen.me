# frozen_string_literal: true

module Public
  class Slice < Hanami::Slice
    config.shared_app_component_keys += %w[assets]

    config.actions.default_headers["Vary"] = "Cookie"

    import keys: %w[auth.session_reader], from: :admin

    import keys: %w[
      contracts.visit_contract operations.hash_visitor operations.record_feed_fetch operations.record_visit
    ], from: :analytics

    import keys: %w[operations.create_message], from: :contact

    import keys: %w[repos.photo_queries store.client], from: :media

    import keys: %w[repos.project_queries repos.work_entry_queries], from: :projects

    import keys: %w[repos.post_queries], from: :posts

    import keys: %w[operations.receive_webmention repos.social_post_queries repos.webmention_queries], from: :social

    export []
  end
end

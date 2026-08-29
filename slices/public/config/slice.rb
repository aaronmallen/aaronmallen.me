# frozen_string_literal: true

module Public
  class Slice < Hanami::Slice
    config.shared_app_component_keys += %w[assets]

    config.actions.default_headers["Vary"] = "Cookie"

    import keys: %w[auth.session_reader], from: :admin

    import keys: %w[operations.hash_visitor operations.record_visit], from: :analytics

    import keys: %w[operations.create_message], from: :contact

    import keys: %w[queries.public_by_tag queries.public_grid queries.work_entries], from: :projects

    import keys: %w[
      queries.latest_published queries.next_published queries.previous_published queries.published
      queries.published_by_slug queries.published_by_tag
    ], from: :posts

    import keys: %w[
      operations.receive_webmention queries.counted_webmentions_for_post queries.listed_webmentions_for_post
      queries.syndication_urls
    ], from: :social

    export %w[operations.find_visitor_address]
  end
end

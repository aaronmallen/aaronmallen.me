# frozen_string_literal: true

module Posts
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/posts"), namespace: Posts)

    import keys: %w[operations.claim_photos operations.release_photos], from: :media

    import keys: %w[networks.all], from: :social

    export %w[
      operations.compose_announcement operations.delete_post operations.lock_post operations.record_post_webmentions
      operations.revise_post_body operations.save_post operations.save_post_seo queries.all queries.by_filter
      queries.by_id queries.by_ids queries.by_status queries.count_by_status queries.dated_between
      queries.edits_for_post queries.latest_published queries.next_published queries.previous_published
      queries.published_by_slug queries.published_page queries.published_page_by_tag queries.scheduled
    ]
  end
end

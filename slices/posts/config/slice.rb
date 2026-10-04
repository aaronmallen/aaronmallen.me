# frozen_string_literal: true

module Posts
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/posts"), namespace: Posts)

    config.shared_app_component_keys += %w[honeybadger.agent]

    import keys: %w[operations.claim_photos operations.release_photos], from: :media

    import keys: %w[links.tagger networks.all queries.mention_directory], from: :social

    export %w[
      operations.act_on_posts operations.compose_announcement operations.delete_post operations.lock_post
      operations.move_post operations.publish_draft
      operations.record_post_webmentions operations.revise_edit_note operations.revise_post_body operations.save_post
      operations.save_post_seo operations.tag_post queries.all
      queries.by_filter queries.by_id queries.by_ids queries.by_status queries.calendar_posts queries.count_by_status
      queries.dated_between queries.edited_at queries.edits_for_post queries.edits_for_posts queries.edits_newest_first
      queries.last_deleted_at queries.last_untagged_at queries.latest_published queries.linkable_posts
      queries.next_published queries.previous_published
      queries.published_by_slug queries.published_page queries.published_page_by_tag queries.scheduled queries.summaries
    ]
  end
end

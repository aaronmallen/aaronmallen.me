# frozen_string_literal: true

module Posts
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/posts"), namespace: Posts)

    config.shared_app_component_keys += %w[honeybadger.agent]

    import keys: %w[operations.claim_photos operations.release_photos], from: :media

    import keys: %w[networks.all operations.expand_for_network repos.person_queries], from: :social

    export %w[
      operations.act_on_posts operations.compose_announcement operations.delete_post operations.lock_post
      operations.move_post operations.publish_draft operations.record_post_webmentions operations.revise_edit_note
      operations.revise_post_body operations.save_post operations.save_post_seo repos.post_queries
    ]
  end
end

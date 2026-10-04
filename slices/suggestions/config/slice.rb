# frozen_string_literal: true

module Suggestions
  class Slice < Hanami::Slice
    autoloader.push_dir(Hanami.app.root.join("lib/suggestions"), namespace: Suggestions)

    import keys: %w[operations.lock_post operations.revise_post_body], from: :posts

    import keys: %w[
      links.tagger networks.all operations.lock_editable_social_post operations.replace_social_post_parts
      queries.mention_directory
    ], from: :social

    export %w[
      operations.accept_suggestion_edits operations.reject_suggestion_edits operations.replace_post_edits
      operations.replace_social_post_edits queries.by_id queries.created_between queries.for_post
      queries.for_social_post queries.open_counts_for_social_posts
    ]
  end
end

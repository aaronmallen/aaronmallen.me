# frozen_string_literal: true

module Suggestions
  class Slice < Hanami::Slice
    import keys: %w[operations.lock_unpublished_post operations.revise_post_body], from: :posts

    import keys: %w[
      operations.check_network_fit operations.lock_editable_social_post
      operations.replace_social_post_parts
    ], from: :social

    export %w[
      operations.accept_suggestion_edits operations.reject_suggestion_edits operations.replace_post_edits
      operations.replace_social_post_edits repos.suggestion_queries
    ]
  end
end

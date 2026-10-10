# frozen_string_literal: true

module Suggestions
  module Operations
    class ReplacePostEdits < Blog::Operation
      PUBLISHED = Blog::Types::PostStatus["published"]

      include Deps[
        contract: "contracts.edits_contract",
        lock_post: "posts.operations.lock_post",
        suggestion_mutations: "repos.suggestion_mutations",
      ]

      def call(post_id, edits:)
        attributes = step validated(contract.call(edits:))

        transaction do
          step unpublished(lock_post.call(post_id))
          suggestion_mutations.replace_for_post(post_id, attributes[:edits])
        end
      end

      private

      def unpublished(post)
        found(post).bind { it.status == PUBLISHED ? Failure(:published) : Success(it) }
      end
    end
  end
end

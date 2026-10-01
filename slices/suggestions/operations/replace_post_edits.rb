# frozen_string_literal: true

module Suggestions
  module Operations
    class ReplacePostEdits < Blog::Operation
      PUBLISHED = Blog::Types::PostStatus["published"]

      include Deps[
        contract: "contracts.edits_contract",
        lock_post: "posts.operations.lock_post",
        suggestion_repo: "repos.suggestion_repo",
      ]

      def call(post_id, edits:)
        attributes = step validated(contract.call(edits:))

        transaction do
          step unpublished(lock_post.call(post_id))
          suggestion_repo.replace_for_post(post_id, attributes[:edits])
        end
      end

      private

      def unpublished(post)
        return Failure(:not_found) unless post
        return Failure(:published) if post.status == PUBLISHED

        Success(post)
      end
    end
  end
end

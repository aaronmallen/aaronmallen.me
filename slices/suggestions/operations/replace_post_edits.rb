# frozen_string_literal: true

module Suggestions
  module Operations
    class ReplacePostEdits < Blog::Operation
      include Deps[
        contract: "contracts.edits_contract",
        lock_unpublished_post: "posts.operations.lock_unpublished_post",
        suggestion_mutations: "repos.suggestion_mutations",
      ]

      def call(post_id, edits:)
        attributes = step validated(contract.call(edits:))

        transaction do
          step lock_unpublished_post.call(post_id)
          suggestion_mutations.replace_for_post(post_id, attributes[:edits])
        end
      end
    end
  end
end

# frozen_string_literal: true

module Suggestions
  module Operations
    class ReplaceSocialPostEdits < Blog::Operation
      include Deps[
        contract: "contracts.edits_contract",
        lock_editable_social_post: "social.operations.lock_editable_social_post",
        suggestion_mutations: "repos.suggestion_mutations",
      ]

      def call(social_post_id, edits:)
        attributes = step validated(contract.call(edits:))

        transaction do
          step editable(lock_editable_social_post.call(social_post_id))
          suggestion_mutations.replace_for_social_post(social_post_id, attributes[:edits])
        end
      end

      private

      def editable(record) = record ? Success(record) : Failure(:already_posted)
    end
  end
end

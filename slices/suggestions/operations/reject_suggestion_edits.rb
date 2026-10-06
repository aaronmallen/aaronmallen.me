# frozen_string_literal: true

module Suggestions
  module Operations
    class RejectSuggestionEdits < Blog::Operation
      include Deps[
        lock_editable_social_post: "social.operations.lock_editable_social_post",
        suggestion_repo: "repos.suggestion_repo",
      ]

      def call(suggestion_id, ids: nil)
        suggestion = step find(suggestion_id)

        transaction do
          step unsent(suggestion)
          suggestion_repo.reject(step(chosen(suggestion, ids)).map(&:id))
        end
      end

      private

      def chosen(suggestion, ids)
        open = suggestion.open_edits
        open = open.select { Array(ids).include?(it.id) } if ids
        open.any? ? Success(open) : Failure(:nothing_open)
      end

      def find(id)
        found(suggestion_repo.by_id(id))
      end

      def unsent(suggestion)
        return Success(suggestion) unless suggestion.social_post_id

        lock_editable_social_post.call(suggestion.social_post_id) ? Success(suggestion) : Failure(:already_posted)
      end
    end
  end
end

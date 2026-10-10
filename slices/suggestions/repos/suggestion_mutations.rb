# frozen_string_literal: true

module Suggestions
  module Repos
    class SuggestionMutations < Blog::DB::Repo
      ACCEPTED = Blog::Types::SuggestionEditStatus["accepted"]
      EDIT_FIELDS = %i[original replacement reason part].freeze
      PENDING = Blog::Types::SuggestionEditStatus["pending"]
      REJECTED = Blog::Types::SuggestionEditStatus["rejected"]
      STALE = Blog::Types::SuggestionEditStatus["stale"]
      OPEN = [PENDING, STALE].freeze

      root :suggestions

      stamped_commands :create

      def accept(ids) = mark(ids, ACCEPTED, from: PENDING)

      def lock_pending(ids) = suggestion_edits.with_ids(ids).with_status(PENDING).in_order.lock.to_a

      def mark_stale(ids) = mark(ids, STALE, from: PENDING)

      def reject(ids) = mark(ids, REJECTED, from: OPEN)

      def replace_for_post(post_id, edits) = replace(edits, post_id:)

      def replace_for_social_post(social_post_id, edits) = replace(edits, social_post_id:)

      private

      def drop_open(target)
        targeted = suggestions.for_target(**target)

        suggestion_edits.for_suggestions(targeted.ids).with_status(OPEN).delete
        targeted.without_edits(suggestion_edits.suggestion_ids).delete
      end

      def insert_edits(suggestion_id, edits)
        rows = edits.each_with_index.map do |edit, index|
          { **EDIT_FIELDS.to_h { [it, edit[it]] }, suggestion_id:, position: index + 1 }
        end

        suggestion_edits.stamped(:create, result: :many).call(rows)
      end

      def mark(ids, status, from:)
        listed = Array(ids)
        return Blog::Constants::EMPTY_ARRAY if listed.empty?

        suggestion_edits.with_ids(listed).with_status(from).mark(status).sort_by(&:position)
      end

      def replace(edits, **target)
        suggestion = transaction do
          drop_open(target)
          created = create(**target)
          insert_edits(created.id, edits)
          created
        end

        suggestions.combine(:suggestion_edits).by_pk(suggestion.id).one
      end
    end
  end
end

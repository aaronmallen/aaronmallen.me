# frozen_string_literal: true

module Suggestions
  module Relations
    class SuggestionEdits < Blog::DB::Relation
      schema :suggestion_edits, infer: true

      def for_suggestions(suggestion_ids) = where(suggestion_id: suggestion_ids)

      def in_order = order(self[:position].asc)

      def mark(status) = stamped(:update, result: :many).call(status:)

      def suggestion_ids = unordered.dataset.select(:suggestion_id)

      def with_ids(ids) = where(id: ids)

      def with_status(status) = where(status:)
    end
  end
end

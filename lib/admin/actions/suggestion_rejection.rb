# frozen_string_literal: true

module Admin
  module Actions
    module SuggestionRejection
      private

      def chosen(suggestion, edit_id)
        open = suggestion.open_edits
        return open if edit_id.empty?

        id = Blog::Types::IdParam[edit_id]
        open.select { it.id == id }
      end

      def reject(response, suggestion, edit_id)
        rejected = reject_edits.call(chosen(suggestion, edit_id).map(&:id))
        toast(response, self.class::REJECTED, count: rejected.length)
      end
    end
  end
end

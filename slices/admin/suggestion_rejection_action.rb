# auto_register: false
# frozen_string_literal: true

module Admin
  class SuggestionRejectionAction < Action
    include Deps[reject_suggestion_edits: "suggestions.operations.reject_suggestion_edits"]

    private

    def chosen(edit_id) = edit_id.empty? ? nil : Array(Blog::Types::IdParam[edit_id])

    def reject(response, suggestion, edit_id)
      case reject_suggestion_edits.call(suggestion.id, ids: chosen(edit_id))
        in Success(*rejected) then toast(response, self.class::REJECTED, count: rejected.length)
        in Failure(:nothing_open) then toast(response, self.class::REJECTED, count: 0)
        in Failure(:already_posted | :not_found) then halt :not_found
        else halt :internal_server_error
      end
    end
  end
end

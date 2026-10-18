# frozen_string_literal: true

module API
  module Endpoints
    class RejectSuggestionEdits < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          edit_ids: {
            type: "array",
            items: Helpers::Schema::ID,
            description: "the edits to reject; every pending and stale edit in the set when you leave it out",
          },
          suggestion_id: Helpers::Schema::ID,
        },
        required: ["suggestion_id"],
      }.freeze

      REPLY = Helpers::Schema.object(
        { suggestion_id: Helpers::Schema::INTEGER, rejected: Helpers::Schema.list(Helpers::Schema::INTEGER) },
      ).freeze

      include Deps[reject_suggestion_edits: "suggestions.operations.reject_suggestion_edits"]

      def handle(suggestion_id:, edit_ids: nil)
        id = suggestion_id

        case reject_suggestion_edits.call(id, ids: edit_ids)
          in Success(*rejected) then Success(suggestion_id: id, rejected: rejected.map(&:id))
          in Failure(:not_found) then missing("suggestion", id)
          in Failure(:nothing_open) then invalid(edit_ids: ["suggestion #{id} has no open edit with those IDs"])
          in Failure(:already_posted) then invalid(suggestion_id: [format(Suggestions::SENT, id)])
          in unmatched then unhandled(unmatched, "could not reject the edits")
        end
      end
    end
  end
end

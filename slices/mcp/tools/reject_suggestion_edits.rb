# frozen_string_literal: true

module MCP
  module Tools
    class RejectSuggestionEdits < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          edit_ids: {
            type: "array",
            items: API::Helpers::Schema::ID,
            description: "the edits to reject; every pending and stale edit in the set when you leave it out",
          },
          suggestion_id: API::Helpers::Schema::ID,
        },
        required: ["suggestion_id"],
      }.freeze

      description "Reject pending or stale edits from one set of suggested edits, as the admin does. " \
                  "The text of the blog post or social post stays as it is"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["write"]

      class << self
        def call(suggestion_id:, server_context:, edit_ids: nil)
          rejected(suggestion_id, dep(:reject_suggestion_edits, server_context).call(suggestion_id, ids: edit_ids))
        end

        private

        def rejected(id, result)
          case result
            in Success(*rejected) then answer(suggestion_id: id, rejected: rejected.map(&:id))
            in Failure(:not_found) then refuse(API::Helpers::Wording.missing("suggestion", id))
            in Failure(:nothing_open) then refuse("suggestion #{id} has no open edit with those IDs")
            in Failure(:already_posted) then refuse(format(AcceptSuggestionEdits::SENT, id))
            else refuse("could not reject the edits")
          end
        end
      end
    end
  end
end

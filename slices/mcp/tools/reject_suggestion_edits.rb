# frozen_string_literal: true

module MCP
  module Tools
    class RejectSuggestionEdits < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          edit_ids: {
            type: "array",
            items: API::Schema::ID,
            description: "the edits to reject; every pending and stale edit in the set when you leave it out",
          },
          suggestion_id: API::Schema::ID,
        },
        required: ["suggestion_id"],
      }.freeze

      description "Reject pending or stale edits from one set of suggested edits, as the admin does. " \
                  "The text of the blog post or social post stays as it is"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(suggestion_id:, server_context:, edit_ids: nil)
          suggestion = dep(:suggestion_by_id, server_context).call(suggestion_id)
          return refuse(format(AcceptSuggestionEdits::UNKNOWN, suggestion_id)) if suggestion.nil?
          return refuse(format(AcceptSuggestionEdits::SENT, suggestion_id)) if sent?(suggestion, server_context)

          reject(suggestion, chosen(suggestion, edit_ids), server_context)
        end

        private

        def chosen(suggestion, edit_ids)
          open = suggestion.open_edits
          edit_ids ? open.select { edit_ids.include?(it.id) } : open
        end

        def reject(suggestion, chosen, server_context)
          return refuse("suggestion #{suggestion.id} has no open edit with those IDs") if chosen.empty?

          rejected = dep(:reject_edits, server_context).call(chosen.map(&:id))
          answer(suggestion_id: suggestion.id, rejected: rejected.map(&:id))
        end

        def sent?(suggestion, server_context)
          suggestion.social_post_id && dep(:editable_social_post, server_context).call(suggestion.social_post_id).nil?
        end
      end
    end
  end
end

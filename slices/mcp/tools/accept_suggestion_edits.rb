# frozen_string_literal: true

module MCP
  module Tools
    class AcceptSuggestionEdits < Base
      PUBLISHED = "the blog post under suggestion %s is published; its edits can no longer apply"
      SENT = "the social post under suggestion %s has been sent"
      UNKNOWN = "no suggestion has the ID %s"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          edit_ids: {
            type: "array",
            items: API::Schema::ID,
            description: "the edits to accept; every pending edit in the set when you leave it out",
          },
          suggestion_id: API::Schema::ID,
        },
        required: ["suggestion_id"],
      }.freeze

      description "Accept pending edits from one set of suggested edits, as the admin does, and write them into " \
                  "the draft or scheduled blog post or unsent social post. An edit whose original text no longer " \
                  "appears once goes stale, and one that would push a social post past a network's limit is " \
                  "refused; both stay out of the text"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(suggestion_id:, server_context:, edit_ids: nil)
          suggestion = dep(:suggestion_by_id, server_context).call(suggestion_id)
          return refuse(format(UNKNOWN, suggestion_id)) if suggestion.nil?

          accepted(suggestion_id, dep(:accept_suggestion_edits, server_context).call(suggestion_id, ids: edit_ids))
        end

        private

        def accepted(id, result)
          case result
          in Success(accepted:, refused:, stale:)
            answer(suggestion_id: id, accepted: ids(accepted), refused: ids(refused), stale: ids(stale))
          in Failure(:not_found) then refuse("suggestion #{id} has no pending edit with those IDs")
          in Failure(:stale) then refuse("the edits you chose on suggestion #{id} have gone stale")
          in Failure(:already_posted) then refuse(format(SENT, id))
          in Failure(:published) then refuse(format(PUBLISHED, id))
          else refuse("could not accept the edits")
          end
        end

        def ids(edits) = edits.map(&:id)
      end
    end
  end
end

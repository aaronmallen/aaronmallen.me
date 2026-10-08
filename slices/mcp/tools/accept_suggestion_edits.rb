# frozen_string_literal: true

module MCP
  module Tools
    class AcceptSuggestionEdits < Base
      EMPTY_PART = "the edits would leave part %s of the social post under suggestion %s empty; nothing changed"
      PUBLISHED = "the blog post under suggestion %s is published; its edits can no longer apply"
      SENT = "the social post under suggestion %s has been sent"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          edit_ids: {
            type: "array",
            items: API::Helpers::Schema::ID,
            description: "the edits to accept; every pending edit in the set when you leave it out",
          },
          suggestion_id: API::Helpers::Schema::ID,
        },
        required: ["suggestion_id"],
      }.freeze

      description "Accept pending edits from one set of suggested edits, as the admin does, and write them into " \
                  "the draft or scheduled blog post or unsent social post. An edit whose original text no longer " \
                  "appears once goes stale, and one that would push a social post past a network's limit is " \
                  "refused; both stay out of the text. Edits that would leave a social post part empty change " \
                  "nothing"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["write"]

      class << self
        def call(suggestion_id:, server_context:, edit_ids: nil)
          suggestion = dep(:suggestion_queries, server_context).by_id(suggestion_id)
          return refuse(API::Helpers::Wording.missing("suggestion", suggestion_id)) if suggestion.nil?

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
            in Failure(:empty_part, part) then refuse(format(EMPTY_PART, part, id))
            in Failure(:published) then refuse(format(PUBLISHED, id))
            else refuse("could not accept the edits")
          end
        end

        def ids(edits) = edits.map(&:id)
      end
    end
  end
end

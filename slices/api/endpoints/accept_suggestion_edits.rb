# frozen_string_literal: true

module API
  module Endpoints
    class AcceptSuggestionEdits < Endpoint
      EMPTY_PART = "the edits would leave part %s of the social post under suggestion %s empty; nothing changed"
      PUBLISHED = "the blog post under suggestion %s is published; its edits can no longer apply"
      SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]

      SCHEMA = {
        additionalProperties: false,
        properties: {
          edit_ids: {
            type: "array",
            items: Helpers::Schema::ID,
            description: "the edits to accept; every pending edit in the set when you leave it out",
          },
          suggestion_id: Helpers::Schema::ID,
        },
        required: ["suggestion_id"],
      }.freeze

      IDS = Helpers::Schema.list(Helpers::Schema::INTEGER)
      REPLY = Helpers::Schema.object(
        { suggestion_id: Helpers::Schema::INTEGER, accepted: IDS, refused: IDS, stale: IDS },
      ).freeze

      include Deps[
        accept_suggestion_edits: "suggestions.operations.accept_suggestion_edits",
        post_queries: "posts.repos.post_queries",
        social_post_queries: "social.repos.social_post_queries",
        suggestion_queries: "suggestions.repos.suggestion_queries",
      ]

      def handle(suggestion_id:, edit_ids: nil)
        id = suggestion_id
        return missing("suggestion", id) if suggestion_queries.by_id(id).nil?

        case accept_suggestion_edits.call(id, ids: edit_ids)
          in Success(accepted:, refused:, stale:)
            Success(suggestion_id: id, accepted: ids(accepted), refused: ids(refused), stale: ids(stale))
          in failure then refused(id, failure)
        end
      end

      private

      def ids(edits) = edits.map(&:id)

      def public_in(fields)
        suggestion = suggestion_queries.by_id(fields[:suggestion_id])
        return if suggestion.nil?
        return "this blog post" if suggestion.post_id && post_queries.shown?(suggestion.post_id)

        "this social post" if social_post_queries.by_id(suggestion.social_post_id)&.status == SCHEDULED
      end

      def refused(id, failure)
        case failure
          in Failure[:empty_part, part] then invalid(edit_ids: [format(EMPTY_PART, part, id)])
          in Failure(:not_found) then invalid(edit_ids: ["suggestion #{id} has no pending edit with those IDs"])
          in Failure(:stale) then invalid(edit_ids: ["the edits you chose on suggestion #{id} have gone stale"])
          in Failure(:already_posted) then invalid(suggestion_id: [format(Suggestions::SENT, id)])
          in Failure(:published) then invalid(suggestion_id: [format(PUBLISHED, id)])
          else failed("could not accept the edits")
        end
      end
    end
  end
end

# frozen_string_literal: true

module API
  module Endpoints
    class ModerateWebmention < Endpoint
      APPROVED = Blog::Types::WebmentionStatus["approved"]
      IGNORED = Blog::Types::WebmentionStatus["ignored"]
      SCOPED = true
      SPAM = Blog::Types::WebmentionStatus["spam"]

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          reason: {
            type: "string",
            description: "why it is spam, kept with a spam verdict; approved and ignored clear it",
          },
          verdict: {
            type: "string",
            enum: [APPROVED, IGNORED, SPAM],
            description:
              "approved shows it on the post; ignored hides it and leaves its author alone; " \
              "spam hides it and ends auto-approval for its author",
          },
        },
        required: %w[id verdict],
      }.freeze

      REPLY = Helpers::Schema.object(
        { id: Helpers::Schema::INTEGER, status: { type: "string", enum: Blog::Types::WebmentionStatus.values } },
      ).freeze

      include Deps[
        moderate_webmention: "social.operations.moderate_webmention",
        webmention_queries: "social.repos.webmention_queries",
      ]

      def handle(id:, verdict:, scopes:, reason: nil)
        return Failure(Structs::Refusal.undeleted("a trusted author")) if verdict == SPAM && distrusts?(id, scopes)

        case moderate_webmention.call(id, verdict, reason:)
          in Success(mention) then Success(id: mention.id, status: mention.status)
          in Failure(:not_found) then missing("webmention", id)
          in unmatched then unhandled(unmatched, "could not moderate the webmention")
        end
      end

      private

      def distrusts?(id, scopes)
        !scopes.include?(OperationTable::DELETE) && webmention_queries.trusted_author_among?(id)
      end

      def going_public(fields) = ("an approved webmention" if fields[:verdict] == APPROVED)
    end
  end
end

# frozen_string_literal: true

module API
  module Endpoints
    class ModerateWebmention < Endpoint
      APPROVED = Blog::Types::WebmentionStatus["approved"]
      IGNORED = Blog::Types::WebmentionStatus["ignored"]
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

      include Deps[moderate_webmention: "social.operations.moderate_webmention"]

      def handle(id:, verdict:, reason: nil)
        case moderate_webmention.call(id, verdict, reason:)
          in Success(mention) then Success(id: mention.id, status: mention.status)
          in Failure(:not_found) then not_found(Helpers::Wording.missing("webmention", id))
          else failed("could not moderate the webmention")
        end
      end
    end
  end
end

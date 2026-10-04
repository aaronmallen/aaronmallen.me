# frozen_string_literal: true

module MCP
  module Tools
    class ModerateWebmention < Base
      APPROVED = Blog::Types::WebmentionStatus["approved"]
      IGNORED = Blog::Types::WebmentionStatus["ignored"]
      SPAM = Blog::Types::WebmentionStatus["spam"]

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: API::Schema::ID,
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

      description "Approve one webmention, so it shows on its blog post, or hide it as ignored or spam"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, verdict:, server_context:, reason: nil)
          case moderate_webmention(server_context).call(id, verdict, reason:)
          in Success(mention) then answer(id: mention.id, status: mention.status)
          in Failure(:not_found) then refuse("no webmention has the ID #{id}")
          else refuse("could not moderate the webmention")
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module API
  module Endpoints
    class CheckPostLinks < Endpoint
      QUEUED = "queued"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          url: { type: "string", description: "one link in the post to check; every link in it when left out" },
        },
        required: %w[id],
      }.freeze

      REPLY = Helpers::Schema.object(
        { id: Helpers::Schema::INTEGER, status: { type: "string", enum: [QUEUED] } },
      ).freeze
      UNAVAILABLE = true

      include Deps[queue_link_check: "posts.operations.queue_link_check"]

      def handle(id:, url: nil)
        case queue_link_check.call(id, Blog::Types::OptionalText[url])
          in Success(_) then Success(id:, status: QUEUED)
          in Failure(:not_found) then missing("published blog post", id)
          in Failure(:queue_unavailable) then Failure(Structs::Refusal.queue_unavailable)
        end
      end
    end
  end
end

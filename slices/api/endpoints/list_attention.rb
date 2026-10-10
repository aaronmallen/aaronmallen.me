# frozen_string_literal: true

module API
  module Endpoints
    class ListAttention < Endpoint
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Helpers::Schema.object(
        {
          attention: Helpers::Schema.list(Serializers::Attention.reference),
          dead_jobs: Helpers::Schema.list(Serializers::DeadJob.reference),
        },
      ).freeze

      include Deps[attention_queries: "activity.repos.attention_queries"]

      def handle
        Success(
          attention: serialized(Serializers::Attention, attention_queries.stalled),
          dead_jobs: serialized(Serializers::DeadJob, attention_queries.dead_jobs),
        )
      end
    end
  end
end

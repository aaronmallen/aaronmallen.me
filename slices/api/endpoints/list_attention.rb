# frozen_string_literal: true

module API
  module Endpoints
    class ListAttention < Endpoint
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Helpers::Schema.object(
        {
          attention: Helpers::Schema.list(Serializers::Attention.reference),
          dead_jobs: Helpers::Schema.list(Serializers::DeadJob.reference),
          dead_job_count: { **Helpers::Schema::INTEGER, description: "every job that ran out of retries" },
        },
      ).freeze

      include Deps[attention_queries: "activity.repos.attention_queries"]

      def handle
        Success(
          attention: serialized(Serializers::Attention, attention_queries.stalled),
          dead_jobs: serialized(Serializers::DeadJob, attention_queries.dead_jobs),
          dead_job_count: attention_queries.dead_job_count,
        )
      end
    end
  end
end

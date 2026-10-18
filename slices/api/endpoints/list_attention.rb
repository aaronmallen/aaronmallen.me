# frozen_string_literal: true

module API
  module Endpoints
    class ListAttention < Endpoint
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Helpers::Schema.object(
        {
          attention: Helpers::Schema.list(Serializers::Attention.reference).merge(
            description: "the worst five rows of each kind, worst first",
          ),
          attention_counts: Helpers::Schema.object(
            Blog::Types::AttentionKind.values.to_h { [it.to_sym, Helpers::Schema::INTEGER] },
          ).merge(description: "every row of each kind, the ones past the five in attention among them"),
          dead_jobs: Helpers::Schema.list(Serializers::DeadJob.reference),
          dead_job_count: { **Helpers::Schema::INTEGER, description: "every job that ran out of retries" },
        },
      ).freeze

      include Deps[attention_queries: "activity.repos.attention_queries"]

      def handle
        capped = attention_queries.capped

        Success(
          attention: serialized(Serializers::Attention, capped[:rows]),
          attention_counts: capped[:counts],
          dead_jobs: serialized(Serializers::DeadJob, attention_queries.dead_jobs),
          dead_job_count: attention_queries.dead_job_count,
        )
      end
    end
  end
end

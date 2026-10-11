# frozen_string_literal: true

module API
  module Serializers
    class ActivitySummary < Serializer
      WORKOUT = Blog::Types::ActivityKind["workout"]
      KINDS = Helpers::Schema.object(
        (Blog::Types::ActivityKind.values - [WORKOUT]).to_h { [it.to_sym, Helpers::Schema::INTEGER] },
        optional: { WORKOUT.to_sym => Helpers::Schema::INTEGER.merge(description: "only for a token with health") },
      ).freeze
      MONTH = "^[0-9]{4}-[0-9]{2}$"
      TOTALS = Helpers::Schema.object(
        { commits: Helpers::Schema::INTEGER, additions: Helpers::Schema::INTEGER, deletions: Helpers::Schema::INTEGER },
      ).freeze

      SCHEMA = Helpers::Schema.object(
        {
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          kinds: KINDS,
          months: {
            type: "object",
            propertyNames: { pattern: MONTH },
            additionalProperties: KINDS,
            description: "the counts month by month, newest first, keyed YYYY-MM; a month with nothing is left out",
          },
          repos: {
            type: "object",
            additionalProperties: TOTALS,
            description: "per repository, the commits and the lines added and deleted",
          },
        },
      ).freeze

      schema_attributes

      def from(summary) = day(summary.fetch(:from))

      def kinds(summary) = summary.fetch(:kinds)

      def months(summary) = summary.fetch(:months)

      def repos(summary) = summary.fetch(:repos)

      def to(summary) = day(summary.fetch(:to))
    end
  end
end

# frozen_string_literal: true

module API
  module Serializers
    class ActivitySummary < Serializer
      KINDS = Schema.object(Blog::Types::ActivityKind.values.to_h { [it.to_sym, Schema::INTEGER] }).freeze
      MONTH = "^[0-9]{4}-[0-9]{2}$"
      TOTALS = Schema.object(
        { commits: Schema::INTEGER, additions: Schema::INTEGER, deletions: Schema::INTEGER },
      ).freeze

      SCHEMA = Schema.object(
        {
          from: Schema::DAY,
          to: Schema::DAY,
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

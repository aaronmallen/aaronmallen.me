# frozen_string_literal: true

module MCP
  module Tools
    class ReadAnalytics < Base
      RANKED = %i[paths referrers countries].freeze
      TOP = 25

      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the first day of the range, as YYYY-MM-DD" },
          to: { type: "string", description: "the last day of the range, as YYYY-MM-DD" },
        },
        required: %w[from to],
      }.freeze

      description "Read the site's analytics over a range: total views, visitors and seconds read, views and " \
                  "visitors day by day, and the top #{TOP} paths, referrers and countries by views. " \
                  "Visitors add up day by day, so one reader on two days counts twice. " \
                  "A referrer of null means a direct visit, and a country of null one the site could not place. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(from:, to:, server_context:)
          case days(from, to)
          in Success(range) then summary(range, server_context)
          in Failure(message) then refuse(message)
          end
        end

        private

        def dated(days) = days.map { it.merge(day: it.fetch(:day).iso8601) }

        def summary(range, server_context)
          found = analytics_between(server_context).call(from: range.first, to: range.last)

          answer(
            from: range.first.iso8601,
            to: range.last.iso8601,
            totals: found.fetch(:totals),
            days: dated(found.fetch(:days)),
            **RANKED.to_h { [it, found.fetch(it).take(TOP)] },
          )
        end
      end
    end
  end
end

# frozen_string_literal: true

module MCP
  module Tools
    class SummarizeActivity < Base
      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the first day of the range, as YYYY-MM-DD" },
          to: { type: "string", description: "the last day of the range, as YYYY-MM-DD" },
        },
        required: %w[from to],
      }.freeze

      description "Count the activity feed over a range: every kind in it by kind, the same counts month by " \
                  "month newest first, and per repository the commits with the lines added and deleted. " \
                  "Counts only, so no commit message, journal entry or title comes back. " \
                  "Give from and to as YYYY-MM-DD; both days sit inside the range, which runs at most " \
                  "#{Blog::DayWindow::LONGEST} days. " \
                  "A year answers in one call, so call this first to see where the work sits, then read the " \
                  "months that matter with read_activity, one month at a time, newest first"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(from:, to:, server_context:)
          first = Blog::TimeZone.parse_day(from)
          last = Blog::TimeZone.parse_day(to)
          return refuse("give from and to as days, such as 2026-01-01") unless first && last
          return refuse("from comes after to") if first > last
          return refuse_long_range if too_long?(first, last)

          summary(first, last, server_context)
        end

        private

        def summary(first, last, server_context)
          range = { from: first, to: last }

          answer(
            from: first.iso8601,
            to: last.iso8601,
            kinds: activity_counts(server_context).call(**range),
            months: activity_counts_by_month(server_context).call(**range),
            repos: activity_commit_totals(server_context).call(**range),
          )
        end
      end
    end
  end
end

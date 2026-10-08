# frozen_string_literal: true

module MCP
  module Tools
    class ListWorkEntries < Base
      SCHEMA = {
        additionalProperties: false,
        properties: Blog::Helpers::DayWindow::RANGE,
        required: %w[from to],
      }.freeze

      description "List the roles on /projects, the work entries, that overlap a range, in the order the page " \
                  "shows them. A role runs by year, from from_year through to_year, and a role with no to_year " \
                  "is one still held. Give from and to as YYYY-MM-DD; a role counts when any year it covers " \
                  "falls inside the range"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(from:, to:, server_context:)
          case Blog::Helpers::DayWindow.days(from, to)
            in Success[first, last] then listed(first, last, server_context)
            in Failure(message) then refuse(message)
          end
        end

        def listed(first, last, server_context)
          entries = dep(:work_entry_queries, server_context).between(from: first, to: last)

          answer(from: first.iso8601, to: last.iso8601, work_entries: entries.map { summary(it) })
        end

        def summary(entry)
          {
            id: entry.id,
            org: entry.org,
            role: entry.role,
            blurb: entry.blurb,
            from_year: entry.from_year,
            to_year: entry.to_year,
            current: entry.current?,
          }
        end
      end
    end
  end
end

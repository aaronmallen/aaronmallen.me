# frozen_string_literal: true

module MCP
  module Tools
    class ListJournalEntries < Base
      SCHEMA = {
        additionalProperties: false,
        properties: { from: DayWindow::DAYS, to: DayWindow::DAYS },
        required: %w[from to],
      }.freeze

      description "List the journal entries in a date range, each with its ID, date, time, whole body and tags. " \
                  "#{DayWindow::PAGING_NOTE}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(from:, to:, server_context:)
          case DayWindow.days(from, to)
          in Success[first, last] then listed(first, last, server_context)
          in Failure(message) then refuse(message)
          end
        end

        private

        def listed(first, last, server_context)
          page = DayWindow.page(first, last, day: :entry_date.to_proc) do |from, to, limit|
            journal_entries_between(server_context).call(from:, to:, limit:)
          end
          rows = page.fetch(:rows)
          window = { from: first.iso8601, to: last.iso8601, count: rows.length, **page.except(:rows) }

          answer(window.merge(entries: rows.map { JournalEntries.fields(it) }))
        end
      end
    end
  end
end

# frozen_string_literal: true

module API
  module Endpoints
    class ListJournalEntries < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { from: Blog::DayWindow::DAYS, to: Blog::DayWindow::DAYS },
        required: %w[from to],
      }.freeze

      REPLY = Schema.object(
        {
          from: Schema::DAY,
          to: Schema::DAY,
          count: Schema::INTEGER,
          partial: Schema::BOOLEAN,
          entries: Schema.list(Serializers::JournalEntry.reference),
        },
        optional: { continue_to: Schema::DAY },
      ).freeze

      include Deps[journal_entries_between: "record.queries.journal_entries_between"]

      def handle(from:, to:)
        case Blog::DayWindow.days(from, to)
        in Success[first, last] then Success(listed(first, last))
        in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def listed(first, last)
        page = Blog::DayWindow.page(first, last, day: :entry_date.to_proc) do |from, to, limit|
          journal_entries_between.call(from:, to:, limit:)
        end
        rows = page.fetch(:rows)
        window = { from: first.iso8601, to: last.iso8601, count: rows.length, **page.except(:rows) }

        window.merge(entries: serialized(Serializers::JournalEntry, rows))
      end
    end
  end
end

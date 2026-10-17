# frozen_string_literal: true

module API
  module Endpoints
    class ListJournalEntries < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: Helpers::DayWindow::DAYS,
          to: Helpers::DayWindow::DAYS,
          tag: { type: "string", description: "a private tag the entry carries; any tag when you leave it out" },
        },
        required: %w[from to],
      }.freeze

      STATS = Helpers::Schema.object(
        {
          entries: Helpers::Schema::INTEGER,
          words: Helpers::Schema::INTEGER,
          streak: Helpers::Schema.object({ days: Helpers::Schema::INTEGER, written: Helpers::Schema::INTEGER }),
        },
      ).merge(description: "the whole journal's entries and words, and the days written of the last few").freeze

      REPLY = Helpers::Schema.paged(
        {
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          count: Helpers::Schema::INTEGER,
          stats: STATS,
          entries: Helpers::Schema.list(Serializers::JournalEntry.reference),
        },
        more: { continue_to: Helpers::Schema::DAY },
      ).freeze

      include Deps[journal_entry_queries: "record.repos.journal_entry_queries"]

      def handle(from:, to:, tag: nil)
        case Helpers::DayWindow.days(from, to)
          in Success[first, last] then Success(listed(first, last, Helpers::Tags.filter(tag)))
          in Failure(message) then bad_window(message)
        end
      end

      private

      def listed(first, last, tag)
        page = Helpers::DayWindow.page(first, last, settings, day: :entry_date.to_proc) do |from, to, limit|
          journal_entry_queries.between(from:, to:, limit:, tag:)
        end
        page.except(:rows).merge(stats:, entries: serialized(Serializers::JournalEntry, page.fetch(:rows)))
      end

      def stats = journal_entry_queries.summary
    end
  end
end

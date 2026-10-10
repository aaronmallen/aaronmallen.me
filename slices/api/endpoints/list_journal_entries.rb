# frozen_string_literal: true

module API
  module Endpoints
    class ListJournalEntries < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: Blog::Helpers::DayWindow::DAYS,
          to: Blog::Helpers::DayWindow::DAYS,
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

      REPLY = Helpers::Schema.object(
        {
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          count: Helpers::Schema::INTEGER,
          partial: Helpers::Schema::BOOLEAN,
          stats: STATS,
          entries: Helpers::Schema.list(Serializers::JournalEntry.reference),
        },
        optional: { continue_to: Helpers::Schema::DAY },
      ).freeze

      include Deps[journal_entry_queries: "record.repos.journal_entry_queries"]

      def handle(from:, to:, tag: nil)
        case Blog::Helpers::DayWindow.days(from, to)
          in Success[first, last] then Success(listed(first, last, tag&.downcase))
          in Failure(message) then bad_window(message)
        end
      end

      private

      def listed(first, last, tag)
        page = Blog::Helpers::DayWindow.page(first, last, day: :entry_date.to_proc) do |from, to, limit|
          journal_entry_queries.between(from:, to:, limit:, tag:)
        end
        rows = page.fetch(:rows)
        window = { from: first.iso8601, to: last.iso8601, count: rows.length, **page.except(:rows) }

        window.merge(stats:, entries: serialized(Serializers::JournalEntry, rows))
      end

      def stats
        { entries: journal_entry_queries.count, words: journal_entry_queries.word_count,
          streak: journal_entry_queries.streak }
      end
    end
  end
end

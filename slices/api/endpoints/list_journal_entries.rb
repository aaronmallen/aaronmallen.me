# frozen_string_literal: true

module API
  module Endpoints
    class ListJournalEntries < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: Blog::DayWindow::DAYS,
          to: Blog::DayWindow::DAYS,
          tag: { type: "string", description: "a private tag the entry carries; any tag when you leave it out" },
        },
        required: %w[from to],
      }.freeze

      STATS = Schema.object(
        {
          entries: Schema::INTEGER,
          words: Schema::INTEGER,
          streak: Schema.object({ days: Schema::INTEGER, written: Schema::INTEGER }),
        },
      ).merge(description: "the whole journal's entries and words, and the days written of the last few").freeze

      REPLY = Schema.object(
        {
          from: Schema::DAY,
          to: Schema::DAY,
          count: Schema::INTEGER,
          partial: Schema::BOOLEAN,
          stats: STATS,
          entries: Schema.list(Serializers::JournalEntry.reference),
        },
        optional: { continue_to: Schema::DAY },
      ).freeze

      include Deps[
        journal_entries_between: "record.queries.journal_entries_between",
        journal_entry_count: "record.queries.journal_entry_count",
        journal_streak: "record.queries.journal_streak",
        journal_word_count: "record.queries.journal_word_count",
      ]

      def handle(from:, to:, tag: nil)
        case Blog::DayWindow.days(from, to)
        in Success[first, last] then Success(listed(first, last, tag&.downcase))
        in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def listed(first, last, tag)
        page = Blog::DayWindow.page(first, last, day: :entry_date.to_proc) do |from, to, limit|
          journal_entries_between.call(from:, to:, limit:, tag:)
        end
        rows = page.fetch(:rows)
        window = { from: first.iso8601, to: last.iso8601, count: rows.length, **page.except(:rows) }

        window.merge(stats:, entries: serialized(Serializers::JournalEntry, rows))
      end

      def stats
        { entries: journal_entry_count.call, words: journal_word_count.call, streak: journal_streak.call }
      end
    end
  end
end

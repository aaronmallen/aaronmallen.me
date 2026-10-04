# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeJournal
      FIELDS = %i[tag].freeze
      SCREEN = Blog::Types::SavedViewScreen["journal"]

      include Deps[
        "settings",
        journal_days: "record.queries.journal_days",
        journal_entry_count: "record.queries.journal_entry_count",
        journal_streak: "record.queries.journal_streak",
        journal_word_count: "record.queries.journal_word_count",
        list_saved_views: "operations.list_saved_views",
      ]

      def call(search: Blog::Constants::EMPTY_STRING, to: nil, filters: Blog::Constants::EMPTY_HASH, now: Time.now)
        {
          days: journal_days.call(
            size: settings.page_size[:admin], to:, **Blog::SearchQuery.parse(search, fields: FIELDS),
          ),
          entries: journal_entry_count.call,
          saved_views: list_saved_views.call(SCREEN, filters),
          streak: journal_streak.call(now:),
          today: Blog::TimeZone.today(now),
          words: journal_word_count.call,
        }
      end
    end
  end
end

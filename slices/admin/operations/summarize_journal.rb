# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeJournal
      FIELDS = %i[tag].freeze
      SCREEN = Blog::Types::SavedViewScreen["journal"]

      include Deps[
        "settings",
        journal_entry_queries: "record.repos.journal_entry_queries",
        list_saved_views: "operations.list_saved_views",
        search_query: "contracts.search_query_contract",
      ]

      def call(search: Blog::Constants::EMPTY_STRING, to: nil, filters: Blog::Constants::EMPTY_HASH, now: Time.now)
        {
          days: journal_entry_queries.days(
            size: settings.page_size[:admin], to:, **search_query.call(query: search, fields: FIELDS).to_h,
          ),
          entries: journal_entry_queries.count,
          saved_views: list_saved_views.call(SCREEN, filters),
          streak: journal_entry_queries.streak(now:),
          today: Blog::TimeZone.today(now),
          words: journal_entry_queries.word_count,
        }
      end
    end
  end
end

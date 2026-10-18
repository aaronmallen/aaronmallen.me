# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeJournal
      FIELDS = %i[tag].freeze
      KIND = Blog::Types::RecordKind["journal_entry"]
      SCREEN = Blog::Types::SavedViewScreen["journal"]

      include Deps[
        "settings",
        journal_entry_queries: "record.repos.journal_entry_queries",
        list_saved_views: "operations.list_saved_views",
        record_link_queries: "links.repos.record_link_queries",
        search_query: "contracts.search_query_contract",
      ]

      def call(search: Blog::Constants::EMPTY_STRING, to: nil, filters: Blog::Constants::EMPTY_HASH, now: Time.now)
        days = find_days(search, to)

        {
          days:,
          linked: record_link_queries.counts(KIND, days.rows.flat_map(&:last).map(&:id)),
          saved_views: list_saved_views.call(SCREEN, filters),
          today: Blog::TimeZone.local_date(now),
          **journal_entry_queries.summary(now:),
        }
      end

      private

      def find_days(search, to)
        journal_entry_queries.days(
          size: settings.page_size[:admin], to:, **search_query.call(query: search, fields: FIELDS).to_h,
        )
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module Operations
    class BuildActivityPage
      FIELDS = %i[repo tag contributor agent model].freeze

      include Deps[
        "settings",
        activity_queries: "activity.repos.activity_queries",
        list_activity_events: "operations.list_activity_events",
        search_query: "contracts.search_query_contract",
      ]

      def call(from: nil, to: nil, types: nil, query: nil, day: nil)
        window = ::Activity::Filters.call(from:, to:, day:, types:)
        filters = { **window.except(:day), text: Blog::Types::Text[query] }
        search = filters.merge(**search_query.call(query: filters[:text], fields: FIELDS).to_h)
        counts = activity_queries.counts(**search.except(:types))

        {
          **timeline(search, window[:day]),
          totals: totals(search, counts),
          filters: filters.merge(counts:, today: Blog::TimeZone.today),
        }
      end

      private

      def timeline(search, day)
        paged = search.merge(day:, size: settings.page_size[:admin])
        found = list_activity_events.call(**paged.except(:to))

        { events: found.rows, older: found.continue_to, newer: list_activity_events.newer_day(**paged) }
      end

      def totals(search, counts)
        {
          events: counts.slice(*search[:types]).values.sum,
          days: activity_queries.day_count(**search),
        }
      end
    end
  end
end

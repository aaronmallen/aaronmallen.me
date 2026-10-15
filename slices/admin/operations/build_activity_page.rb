# frozen_string_literal: true

module Admin
  module Operations
    class BuildActivityPage
      FIELDS = %i[repo tag contributor agent model].freeze

      include Deps[
        "settings",
        activity_queries: "activity.repos.activity_queries",
        health_queries: "health.repos.health_queries",
        list_activity_events: "operations.list_activity_events",
        search_query: "contracts.search_query_contract",
      ]

      def call(from: nil, to: nil, types: nil, query: nil, day: nil)
        window = filter_window(from:, to:, day:, types:)
        filters = { **window.except(:day), text: Blog::Types::Text[query] }
        search = filters.merge(**search_query.call(query: filters[:text], fields: FIELDS).to_h)
        counts = activity_queries.counts(**search.except(:types))

        {
          **timeline(search, window[:day], counts),
          filters: filters.merge(counts:, today: Blog::TimeZone.today),
        }
      end

      private

      def filter_window(**) = ::Activity::Contracts::FiltersContract.new.call(**).to_h

      def health(events)
        return Blog::Constants::EMPTY_HASH if events.empty?

        health_queries.days(from: events.last.occurred_on, to: events.first.occurred_on)
      end

      def timeline(search, day, counts)
        found = list_activity_events.call(**search, day:, size: settings.page_size[:admin])

        {
          **found.slice(:events, :older, :newer),
          health: health(found[:events]),
          totals: { events: counts.slice(*search[:types]).values.sum, days: found[:days] },
        }
      end
    end
  end
end

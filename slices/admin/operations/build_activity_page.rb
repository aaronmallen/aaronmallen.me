# frozen_string_literal: true

module Admin
  module Operations
    class BuildActivityPage
      DEFAULT_RANGE = Blog::Constants::ACTIVITY_RANGES.first
      FIELDS = %i[repo tag].freeze
      TYPES = Structs::ActivityEvent::KINDS

      include Deps[
        "settings",
        activity_counts: "activity.queries.activity_counts",
        activity_day_count: "activity.queries.activity_day_count",
        list_activity_events: "operations.list_activity_events",
      ]

      def call(from: nil, to: nil, types: nil, query: nil, day: nil)
        filters = filters(from, to, types, query)
        search = filters.merge(**SearchQuery.parse(filters[:text], fields: FIELDS))
        counts = activity_counts.call(**search.slice(:from, :to, :repos, :text, :tags))

        {
          **timeline(search, day(day, filters)),
          totals: totals(search, counts),
          filters: filters.merge(counts:, today: Blog::TimeZone.today),
        }
      end

      private

      def day(chosen, filters)
        picked = Blog::Types::DateParam[chosen]

        picked && (filters[:from]..filters[:to]).cover?(picked) ? picked : filters[:to]
      end

      def filters(from, to, chosen, query)
        last = Blog::Types::DateParam[to] || Blog::TimeZone.today
        first = Blog::Types::DateParam[from] || (last - (DEFAULT_RANGE - 1))

        { from: [first, last].min, to: last, types: types(chosen), text: Blog::Types::Text[query] }
      end

      def timeline(search, day)
        paged = search.merge(day:, size: settings.page_size[:admin])
        found = list_activity_events.call(**paged.except(:to))

        { events: found.rows, older: found.continue_to, newer: list_activity_events.newer_day(**paged) }
      end

      def totals(search, counts)
        {
          events: counts.slice(*search[:types]).values.sum,
          days: activity_day_count.call(**search.slice(:from, :to, :types, :repos, :text, :tags)),
        }
      end

      def types(chosen)
        return TYPES unless chosen.is_a?(Hash)

        TYPES.select { Blog::Types::Checkbox[chosen[it.to_sym]] }
      end
    end
  end
end

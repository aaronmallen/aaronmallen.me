# frozen_string_literal: true

module Admin
  module Operations
    class BuildActivityPage
      DEFAULT_RANGE = Blog::Constants::ACTIVITY_RANGES.first
      FIELDS = %i[repo tag].freeze
      TYPES = Structs::ActivityEvent::KINDS

      include Deps[
        activity_counts: "activity.queries.activity_counts",
        list_activity_events: "operations.list_activity_events",
      ]

      def call(from: nil, to: nil, types: nil, query: nil)
        filters = filters(from, to, types, query)
        search = filters.merge(**SearchQuery.parse(filters[:text], fields: FIELDS))

        { events: list_activity_events.call(**search), filters: filters.merge(**rail(search)) }
      end

      private

      def filters(from, to, chosen, query)
        last = Blog::Types::DateParam[to] || Blog::TimeZone.today
        first = Blog::Types::DateParam[from] || (last - (DEFAULT_RANGE - 1))

        { from: [first, last].min, to: last, types: types(chosen), text: Blog::Types::Text[query] }
      end

      def rail(search)
        {
          counts: activity_counts.call(**search.slice(:from, :to, :repos, :text, :tags)),
          today: Blog::TimeZone.today,
        }
      end

      def types(chosen)
        return TYPES unless chosen.is_a?(Hash)

        TYPES.select { Blog::Types::Checkbox[chosen[it.to_sym]] }
      end
    end
  end
end

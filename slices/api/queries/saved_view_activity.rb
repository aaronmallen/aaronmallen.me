# frozen_string_literal: true

require "dry/monads"

module API
  module Queries
    class SavedViewActivity
      DEFAULT_RANGE = Blog::Constants::ACTIVITY_RANGES.first
      FIELDS = %i[repo tag].freeze
      KINDS = Blog::Constants::ACTIVITY_SCREEN_KINDS

      include Dry::Monads[:result]
      include Deps[activity_between: "activity.queries.activity_between"]

      def call(filters, continue_to: nil, **)
        first, last = days(filters)
        search = { types: types(filters["types"]), **Blog::SearchQuery.parse(filters["q"], fields: FIELDS) }
        day = start(continue_to || Blog::Types::DateParam[filters["day"]], first, last)

        Success(Blog::DayWindow.page(first, day, day: :occurred_on.to_proc) do |from, to, limit|
          activity_between.call(from:, to:, limit:, **search)
        end)
      end

      private

      def days(filters)
        last = Blog::Types::DateParam[filters["to"]] || Blog::TimeZone.today
        first = Blog::Types::DateParam[filters["from"]] || (last - (DEFAULT_RANGE - 1))

        [[first, last].min, last]
      end

      def start(picked, first, last) = picked && (first..last).cover?(picked) ? picked : last

      def types(chosen)
        return KINDS unless chosen.is_a?(::Hash)

        KINDS.select { Blog::Types::Checkbox[chosen[it]] }
      end
    end
  end
end

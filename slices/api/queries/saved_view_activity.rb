# frozen_string_literal: true

require "dry/monads"

module API
  module Queries
    class SavedViewActivity
      FIELDS = %i[repo tag].freeze

      include Dry::Monads[:result]
      include Deps[
        activity_between: "activity.queries.activity_between", activity_filters: "activity.queries.activity_filters",
      ]

      def call(filters, continue_to: nil, **)
        window = activity_filters.call(
          from: filters["from"], to: filters["to"], day: continue_to || filters["day"], types: filters["types"],
        )
        search = { types: window[:types], **Blog::SearchQuery.parse(filters["q"], fields: FIELDS) }

        Success(Blog::DayWindow.page(window[:from], window[:day], day: :occurred_on.to_proc) do |from, to, limit|
          activity_between.call(from:, to:, limit:, **search)
        end)
      end
    end
  end
end

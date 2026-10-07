# frozen_string_literal: true

require "dry/monads"

module API
  module Queries
    class SavedViewActivity
      FIELDS = %i[repo tag contributor agent model].freeze

      include Dry::Monads[:result]
      include Deps[activity_queries: "activity.repos.activity_queries"]

      def call(filters, continue_to: nil, **)
        window = ::Activity::Filters.call(
          from: filters["from"], to: filters["to"], day: continue_to || filters["day"], types: filters["types"],
        )
        search = { types: window[:types], **Blog::SearchQuery.parse(filters["q"], fields: FIELDS) }

        Success(Blog::DayWindow.page(window[:from], window[:day], day: :occurred_on.to_proc) do |from, to, limit|
          activity_queries.between(from:, to:, limit:, **search)
        end)
      end
    end
  end
end

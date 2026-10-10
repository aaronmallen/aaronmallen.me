# frozen_string_literal: true

require "rack/utils"

module Admin
  module UI
    module Components
      module Activity
        class DayPager < Component
          Days = Data.define(:newer_query, :older_query)

          prop :from, Blog::Types::Date
          prop :newer, Blog::Types::Date.optional
          prop :older, Blog::Types::Date.optional
          prop :text, Blog::Types::String
          prop :to, Blog::Types::Date
          prop :types, Blog::Types::Array.of(Blog::Types::String)

          def view_template
            Pager(page: Days.new(newer_query: @newer, older_query: @older), href: method(:href))
          end

          private

          def href(day)
            query = Filters.query(from: @from, to: @to, types: @types, text: @text)
            query[:day] = day.iso8601 unless day == @to

            "#{path(:admin_activity)}?#{Rack::Utils.build_nested_query(query)}"
          end
        end
      end
    end
  end
end

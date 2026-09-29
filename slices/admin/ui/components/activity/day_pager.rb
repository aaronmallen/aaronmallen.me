# frozen_string_literal: true

require "rack/utils"

module Admin
  module UI
    module Components
      module Activity
        class DayPager < Component
          LABEL = "ui.components.pager.label"
          NEWER = "ui.components.pager.newer"
          OLDER = "ui.components.pager.older"

          prop :from, Blog::Types::Date
          prop :newer, Blog::Types::Date.optional
          prop :older, Blog::Types::Date.optional
          prop :text, Blog::Types::String
          prop :to, Blog::Types::Date
          prop :types, Blog::Types::Array.of(Blog::Types::String)

          def view_template
            return unless @newer || @older

            nav(class: "pager", aria: { label: t(LABEL) }) do
              link(@newer, rel: "prev", label: NEWER, icon: "fa-arrow-left")
              link(@older, rel: "next", label: OLDER, icon: "fa-arrow-right")
            end
          end

          private

          def href(day)
            query = Filters.query(from: @from, to: @to, types: @types, text: @text)
            query[:day] = day.iso8601 unless day == @to

            "#{path(:admin_activity)}?#{Rack::Utils.build_nested_query(query)}"
          end

          def link(day, rel:, label:, icon:)
            return unless day

            a(class: ["pager-link", rel], href: href(day), rel:) do
              i(class: ["fa-solid", icon], aria: { hidden: "true" })
              span { t(label) }
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Filters < Component
          SEARCH_ID = "tasks-q"

          prop :query, Blog::Types::String
          prop :tab, Blog::Types::String
          prop :range, Blog::Types::Hash

          def view_template
            AutoForm(action: path(:admin_tasks), role: "search", class: "tasks-filters") do
              input(type: "hidden", name: "filter", value: @tab)
              @range.each { |name, day| input(type: "hidden", name:, value: day.iso8601) }
              SearchField(
                id: SEARCH_ID, label: t(".search"), name: "q", value: @query, placeholder: t(".search_placeholder"),
              )
            end
            clear_range unless @range.empty?
          end

          private

          def clear_range
            href = path(:admin_tasks, **{ filter: @tab, q: @query }.reject { |_, value| value.empty? })

            Button(href:, variant: :gh, small: true, icon: "fa-solid fa-xmark", aria: { label: t(".clear_range") }) do
              plain @range.values.uniq.map { l(it, format: :short) }.join(" → ")
            end
          end
        end
      end
    end
  end
end

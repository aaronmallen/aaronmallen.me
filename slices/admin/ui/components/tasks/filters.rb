# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Filters < Component
          SEARCH_ID = "tasks-q"

          prop :query, Blog::Types::String
          prop :tab, Blog::Types::String

          def view_template
            form(
              action: path(:admin_tasks), method: "get", role: "search", class: "tasks-filters",
              data: { autosubmit: "" },
            ) do
              input(type: "hidden", name: "filter", value: @tab)
              search_field
              noscript { Button(type: "submit", small: true) { t(".apply") } }
            end
          end

          private

          def search_field
            label(class: "sr-only", for: SEARCH_ID) { t(".search") }
            Input(
              type: "search", id: SEARCH_ID, name: "q", value: @query, placeholder: t(".search_placeholder"),
            )
          end
        end
      end
    end
  end
end

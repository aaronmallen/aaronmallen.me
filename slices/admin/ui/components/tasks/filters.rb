# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Filters < Component
          SEARCH_ID = "tasks-q"

          prop :query, Blog::Types::String
          prop :tab, Blog::Types::String
          prop :saved_views, Blog::Types::Hash

          def view_template
            SavedViews(**@saved_views)
            AutoForm(action: path(:admin_tasks), role: "search", class: "tasks-filters") do
              input(type: "hidden", name: "filter", value: @tab)
              search_field
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

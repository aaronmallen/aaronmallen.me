# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Filters < Component
          ALL_TYPES = "all"
          SEARCH_ID = "tasks-q"

          prop :query, Blog::Types::String
          prop :tab, Blog::Types::String
          prop :type, Blog::Types::String
          prop :types, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            form(
              action: path(:admin_tasks), method: "get", role: "search", class: "tasks-filters",
              data: { autosubmit: "" },
            ) do
              input(type: "hidden", name: "filter", value: @tab)
              search_field
              type_field
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

          def type_field
            label(class: "sr-only", for: "tasks-type") { t(".type") }
            Select(id: "tasks-type", name: "type", options: type_options, selected: @type)
          end

          def type_options = { ALL_TYPES => t(".all_types") }.merge(@types.to_h { [it.id.to_s, it.name] })
        end
      end
    end
  end
end

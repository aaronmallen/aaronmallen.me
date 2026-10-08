# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class QuickAdd < Component
          prop :filter, Blog::Types::String
          prop :placeholder, Blog::Types::String
          prop :sprint_on, Blog::Types::Date.optional, default: nil

          def view_template
            Form(action: path(:admin_create_task), class: "quick-add") do
              input(type: "hidden", name: "filter", value: @filter)
              input(type: "hidden", name: "task[sprint_on]", value: @sprint_on.iso8601) if @sprint_on
              Icon("fa-solid fa-plus")
              input(
                type: "text", name: "task[title]", required: true, autocomplete: "off", placeholder: @placeholder,
                aria: { label: @placeholder },
              )
              Button(type: "submit", small: true) { t(".add") }
            end
          end
        end
      end
    end
  end
end

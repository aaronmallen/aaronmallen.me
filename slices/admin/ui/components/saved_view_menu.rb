# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SavedViewMenu < Component
        prop :label, Blog::Types::String
        prop :icon, Blog::Types::String
        prop :quiet, Blog::Types::Bool, default: false

        def view_template(&)
          details(class: "saved-view-menu") do
            summary(class: ["btn", "sm", ("gh" if @quiet)], title: (@label if @quiet)) do
              i(class: @icon, aria: { hidden: "true" })
              span(class: ("sr-only" if @quiet)) { @label }
            end
            div(class: "saved-view-panel", &)
          end
        end
      end
    end
  end
end

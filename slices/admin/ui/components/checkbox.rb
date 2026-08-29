# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Checkbox < Component
        prop :label, Blog::Types::String
        prop :name, Blog::Types::String
        prop :checked, Blog::Types::Bool, default: false
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          label(class: "choice") do
            input(type: "hidden", name: @name, value: "0")
            input(**mix(control_attributes, @attributes))
            span { @label }
          end
        end

        private

        def control_attributes
          { class: "check", type: "checkbox", name: @name, value: Blog::Constants::CHECKED, checked: @checked }
        end
      end
    end
  end
end

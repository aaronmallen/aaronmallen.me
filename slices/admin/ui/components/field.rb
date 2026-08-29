# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Field < Component
        prop :label, Blog::Types::String
        prop :id, Blog::Types::String.optional, default: nil

        def view_template(&)
          div(class: "field") do
            render_label
            yield
          end
        end

        private

        def render_label
          return span(class: "f") { @label } unless @id

          label(class: "f", for: @id) { @label }
        end
      end
    end
  end
end

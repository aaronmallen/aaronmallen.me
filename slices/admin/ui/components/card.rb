# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Card < Component
        prop :label, Blog::Types::String.optional
        prop :title, Blog::Types::String.optional
        prop :attributes, Blog::Types::Hash, :**

        def side(&block)
          @side = block
          nil
        end

        def view_template(&)
          vanish(&)

          section(**mix({ class: "card" }, @attributes)) do
            render_head if @label || @title || @side
            div(class: "card-body", &)
          end
        end

        private

        def render_head
          header(class: "card-head") do
            div do
              span(class: "card-label") { @label } if @label
              h2(class: "card-title") { @title } if @title
            end
            div(class: "card-side", &@side) if @side
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Card < Component
        prop :label, Blog::Types::String.optional
        prop :title, Blog::Types::String.optional
        prop :note, Blog::Types::String.optional, default: nil
        prop :note_class, Blog::Types::String.enum("card-note", "settings-count"), default: "card-note"
        prop :blurb, Blog::Types::String.optional, default: nil
        prop :empty, Blog::Types::String.optional, default: nil
        prop :attributes, Blog::Types::Hash, :**

        def side(&block)
          @side = block
          nil
        end

        def view_template(&)
          vanish(&)

          section(**mix({ class: "card" }, @attributes)) do
            render_head if @label || @title || @side || @note
            div(class: "card-body") { render_body(&) }
          end
        end

        private

        def render_body
          p(class: "card-blurb") { @blurb } if @blurb
          return Empty { @empty } if @empty

          yield(self) if block_given?
        end

        def render_head
          header(class: "card-head") do
            div do
              span(class: "card-label") { @label } if @label
              h2(class: "card-title") { @title } if @title
            end
            render_side if @side || @note
          end
        end

        def render_side
          div(class: "card-side") do
            span(class: @note_class) { @note } if @note
            @side&.call(self)
          end
        end
      end
    end
  end
end

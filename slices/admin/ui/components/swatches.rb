# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Swatches < Component
        COLORS = Blog::Types::TagColor.values.freeze
        LABEL_KEYS = COLORS.to_h { [it, ".colors.#{Blog::UI::Components::Pill.for_tag_color(it)}"] }.freeze

        prop :name, Blog::Types::String
        prop :scope, Blog::Types::String
        prop :selected, Blog::Types::String.optional, default: nil
        prop :submit, Blog::Types::Bool, default: false

        def view_template
          div(class: "swatches") { COLORS.each { @submit ? swatch_button(it) : swatch_radio(it) } }
        end

        private

        def hue(color) = Blog::UI::Components::Pill.for_tag_color(color)

        def id_for(color) = "#{@scope}-#{color}"

        def label_for(color) = t(LABEL_KEYS.fetch(color))

        def swatch_button(color)
          button(
            type: "submit", name: @name, value: color, class: swatch_class(color),
            aria: { label: t(".pick", color: label_for(color)), pressed: (color == @selected).to_s },
          )
        end

        def swatch_class(color) = ["swatch", hue(color).to_s, ("on" if color == @selected)]

        def swatch_radio(color)
          input(type: "radio", class: "sr-only", id: id_for(color), name: @name, value: color,
                checked: color == @selected)
          label(for: id_for(color), class: swatch_class(color)) { span(class: "sr-only") { label_for(color) } }
        end
      end
    end
  end
end

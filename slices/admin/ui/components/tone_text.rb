# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ToneText < Component
        prop :color, Blog::Types::Symbol.enum(*Blog::UI::Components::Pill::COLORS).optional
        prop :icon, Blog::UI::Components::Icon::NAME.optional, default: nil

        def view_template(&)
          return span(class: classes, &) unless @icon

          span(class: classes) { IconLabel(icon: @icon, &) }
        end

        private

        def classes = ["tone-text", @color&.to_s]
      end
    end
  end
end

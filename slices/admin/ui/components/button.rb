# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Button < Component
        prop :variant, Blog::Types::Symbol.enum(:pri, :warn, :gh).optional
        prop :small, Blog::Types::Bool, default: false
        prop :type, Blog::Types::String.enum("button", "submit", "reset"), default: "button"
        prop :disabled, Blog::Types::Bool, default: false
        prop :href, Blog::Types::String.optional, default: nil
        prop :icon, Blog::UI::Components::Icon::NAME.optional, default: nil
        prop :attributes, Blog::Types::Hash, :**

        def view_template(&)
          return a(**mix(link_attributes, @attributes)) { inner(&) } if @href

          button(**mix(button_attributes, @attributes)) { inner(&) }
        end

        private

        def button_attributes = { type: @type, class: classes, disabled: @disabled }

        def classes = ["bt", @variant&.to_s, ("sm" if @small)]

        def inner
          Icon(@icon) if @icon
          yield if block_given?
        end

        def link_attributes = { href: @href, class: classes }
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Button < Component
        prop :variant, Blog::Types::Symbol.enum(:pri, :warn, :gh).optional
        prop :small, Blog::Types::Bool, default: false
        prop :type, Blog::Types::String.enum("button", "submit", "reset"), default: "button"
        prop :disabled, Blog::Types::Bool, default: false
        prop :attributes, Blog::Types::Hash, :**

        def view_template(&)
          button(**mix(own_attributes, @attributes), &)
        end

        private

        def own_attributes = { type: @type, class: ["btn", @variant&.to_s, ("sm" if @small)], disabled: @disabled }
      end
    end
  end
end

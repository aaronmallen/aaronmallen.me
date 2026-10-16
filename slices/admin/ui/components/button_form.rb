# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ButtonForm < Component
        prop :action, Blog::Types::String
        prop :label, Blog::Types::String
        prop :variant, Blog::Types::Symbol.enum(:pri, :warn, :gh).optional, default: nil
        prop :icon, Blog::UI::Components::Icon::NAME.optional, default: nil
        prop :icon_only, Blog::Types::Bool, default: false
        prop :confirm, Blog::Types::String.optional, default: nil
        prop :morph, Blog::Types::Bool, default: false
        prop :hidden, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
        prop :button, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          Form(action: @action, **@attributes, data: { morph: (true if @morph), confirm: @confirm }) do
            HiddenFields(values: @hidden)
            yield if block_given?
            Button(type: "submit", variant: @variant, small: true, icon: @icon, label: name, **@button) { @label }
          end
        end

        private

        def name = (@label if @icon_only)
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module UI
    module Components
      class DeleteForm < Component
        ICON = "fa-regular fa-trash-can"

        prop :action, Blog::Types::String
        prop :confirm, Blog::Types::String
        prop :label, Blog::Types::String
        prop :morph, Blog::Types::Bool, default: false
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          Form(action: @action, **@attributes, data: { morph: (true if @morph), confirm: @confirm }) do
            yield if block_given?
            Button(variant: :warn, type: "submit", small: true, icon: ICON) { @label }
          end
        end
      end
    end
  end
end

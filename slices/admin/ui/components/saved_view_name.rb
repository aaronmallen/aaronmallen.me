# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SavedViewName < Component
        MAX = 100

        prop :id, Blog::Types::String
        prop :submit, Blog::Types::String
        prop :value, Blog::Types::String.optional, default: nil

        def view_template
          Field(label: t(".name"), id: @id) do
            Input(id: @id, name: "saved_view[name]", value: @value, required: true, maxlength: MAX, autocomplete: "off")
          end
          Button(type: "submit", variant: :pri, small: true) do
            i(class: "fa-regular fa-floppy-disk", aria: { hidden: "true" })
            span { @submit }
          end
        end
      end
    end
  end
end

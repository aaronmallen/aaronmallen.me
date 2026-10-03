# frozen_string_literal: true

module Admin
  module UI
    module Components
      class BulkCheck < Component
        prop :form, Blog::Types::String
        prop :value, Blog::Types::Integer
        prop :label, Blog::Types::String
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          label(**mix({ class: "bulk-pick" }, @attributes)) do
            input(type: "checkbox", class: "check", name: BulkBar::FIELD, value: @value, form: @form,
                  aria: { label: @label })
          end
        end
      end
    end
  end
end

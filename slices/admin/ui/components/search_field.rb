# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SearchField < Component
        prop :id, Blog::Types::String
        prop :label, Blog::Types::String
        prop :value, Blog::Types::String.optional
        prop :name, Blog::Types::String
        prop :placeholder, Blog::Types::String
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          label(class: "sr-only", for: @id) { @label }
          Input(type: "search", id: @id, name: @name, value: @value, placeholder: @placeholder, **@attributes)
        end
      end
    end
  end
end

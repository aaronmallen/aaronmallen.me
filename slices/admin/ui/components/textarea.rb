# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Textarea < Component
        prop :value, Blog::Types::String.optional
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          textarea(**mix({ class: "inp" }, @attributes)) { @value }
        end
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Select < Component
        prop :options, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::String)
        prop :selected, Blog::Types::String.optional
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          select(**mix({ class: "inp" }, @attributes)) do
            @options.each do |value, text|
              option(value:, selected: value == @selected) { text }
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SavedViewFields < Component
        prop :return_to, Blog::Types::String
        prop :filters, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

        def view_template
          hidden("return_to", @return_to)
          @filters.each do |name, value|
            next hidden("filters[#{name}]", value) unless value.is_a?(::Hash)

            value.each { |key, inner| hidden("filters[#{name}][#{key}]", inner) }
          end
        end

        private

        def hidden(name, value) = input(type: "hidden", name:, value:)
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SavedViewFields < Component
        prop :return_to, Blog::Types::String
        prop :filters, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

        def view_template
          HiddenFields(values: { "return_to" => @return_to, **fields })
        end

        private

        def fields
          @filters.each_with_object({}) do |(name, value), fields|
            next fields["filters[#{name}]"] = value unless value.is_a?(::Hash)

            value.each { |key, inner| fields["filters[#{name}][#{key}]"] = inner }
          end
        end
      end
    end
  end
end

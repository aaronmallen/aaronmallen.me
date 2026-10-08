# frozen_string_literal: true

module SavedViews
  module Contracts
    class FiltersContract < Blog::Contract
      KNOWN = {
        Blog::Types::SavedViewScreen["activity"] => %w[from to types q day],
        Blog::Types::SavedViewScreen["journal"] => %w[q to],
        Blog::Types::SavedViewScreen["posts"] => %w[status],
        Blog::Types::SavedViewScreen["tasks"] => %w[filter pool q],
      }.freeze

      params do
        optional(:screen).value(:any)
        optional(:filters).value(:any)

        after(:value_coercer) { |result| result.update(filters: FiltersContract.keep(**result.to_h)) }
      end

      def self.keep(screen: nil, filters: nil)
        named = Blog::Types::Fields[filters].to_h { |key, value| [key.to_s, nested(value)] }

        named.slice(*names(screen))
      end

      def self.names(screen) = KNOWN.fetch(screen, Blog::Constants::EMPTY_ARRAY)

      def self.nested(value) = value.is_a?(::Hash) ? value.transform_keys(&:to_s) : value
      private_class_method :nested
    end
  end
end

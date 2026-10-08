# frozen_string_literal: true

module Activity
  module Contracts
    class FiltersContract < Blog::Contract
      DEFAULT_RANGE = Blog::Types::RangePreset.values.first
      KINDS = Blog::Types::ActivityScreenKind.values

      params do
        optional(:from).value(Blog::Types::DateParam)
        optional(:to).value(Blog::Types::DateParam)
        optional(:day).value(Blog::Types::DateParam)
        optional(:types).value(:any)

        after(:value_coercer) { |result| result.update(FiltersContract.window(**result.to_h)) }
      end

      def self.kinds(chosen)
        return KINDS unless chosen.is_a?(::Hash)

        ticked = chosen.transform_keys(&:to_s)
        KINDS.select { Blog::Types::Checkbox[ticked[it]] }
      end
      private_class_method :kinds

      def self.window(from: nil, to: nil, day: nil, types: nil)
        last = to || Blog::TimeZone.today
        first = [from || (last - (DEFAULT_RANGE - 1)), last].min

        { from: first, to: last, day: day && (first..last).cover?(day) ? day : last, types: kinds(types) }
      end
    end
  end
end

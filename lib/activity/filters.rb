# frozen_string_literal: true

module Activity
  module Filters
    DEFAULT_RANGE = Blog::Types::RangePreset.values.first
    KINDS = Blog::Types::ActivityScreenKind.values

    module_function

    def call(from: nil, to: nil, day: nil, types: nil)
      last = Blog::Types::DateParam[to] || Blog::TimeZone.today
      first = [Blog::Types::DateParam[from] || (last - (DEFAULT_RANGE - 1)), last].min

      { from: first, to: last, day: day(Blog::Types::DateParam[day], first, last), types: kinds(types) }
    end

    def day(picked, first, last) = picked && (first..last).cover?(picked) ? picked : last

    def kinds(chosen)
      return KINDS unless chosen.is_a?(::Hash)

      ticked = chosen.transform_keys(&:to_s)
      KINDS.select { Blog::Types::Checkbox[ticked[it]] }
    end
  end
end

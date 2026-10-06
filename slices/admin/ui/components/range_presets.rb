# frozen_string_literal: true

module Admin
  module UI
    module Components
      class RangePresets < Component
        prop :ranges, Blog::Types::Array.of(Blog::Types::Integer)
        prop :today, Blog::Types::Date
        prop :from, Blog::Types::Date
        prop :to, Blog::Types::Date

        def href(&block)
          @href = block
          nil
        end

        def view_template(&)
          vanish(&)

          Field(label: t(".range")) do
            SegmentedLinks(label: t(".range"), items: @ranges.map { preset(it) })
          end
        end

        private

        def preset(days)
          range = (@today - (days - 1))..@today

          { href: @href.call(range), text: t(".preset", count: days), current: range == (@from..@to) }
        end
      end
    end
  end
end

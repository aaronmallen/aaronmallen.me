# frozen_string_literal: true

module Blog
  module UI
    module Components
      class Pill < Component
        COLORS = %i[green pink blue violet sand orange].freeze
        TAG_COLORS = COLORS.to_h { [Blog::Types::TagColor["mk-#{it}"], it] }.freeze

        prop :color, Blog::Types::Symbol.enum(*COLORS).optional

        def self.for_tag_color(value) = TAG_COLORS[value]

        def view_template(&)
          span(class: ["pill", @color&.to_s], &)
        end
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module UI
    module Components
      class TodayLine < Component
        prop :label, Blog::Types::String
        prop :href, Blog::Types::String
        prop :warn, Blog::Types::Bool, default: false
        prop :data, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

        def view_template(&)
          a(class: "today-line", href: @href, data: @data) do
            span { @label }
            span(class: ["today-line-value", ("warn" if @warn)], &)
          end
        end
      end
    end
  end
end

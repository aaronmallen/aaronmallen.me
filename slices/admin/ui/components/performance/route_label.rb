# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Performance
        class RouteLabel < Component
          prop :route, Blog::Types::String.optional
          prop :verb, Blog::Types::String

          def view_template
            span(class: "perf-verb") { @verb }
            whitespace
            return span(class: "perf-path none") { t(".no_route") } unless @route

            span(class: "perf-path") { @route }
          end
        end
      end
    end
  end
end

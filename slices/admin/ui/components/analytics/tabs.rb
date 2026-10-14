# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class Tabs < Component
          TABS = { traffic: [:admin_analytics, ".traffic"], performance: [:admin_performance, ".performance"] }.freeze

          prop :current, Blog::Types::Symbol.enum(*TABS.keys)
          prop :range, Blog::Types::AnalyticsRange
          prop :action, Blog::Types::String
          prop :keep, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

          def view_template
            div(class: "perf-tabs") do
              nav(class: "perf-tabs-list", aria: { label: t(".label") }) do
                TABS.each do |name, (route, label)|
                  tab(name, route, label)
                end
              end
              RangeSwitch(action: @action, range: @range, keep: @keep)
            end
          end

          private

          def current(name)
            return unless name == @current

            @keep.empty? ? "page" : "true"
          end

          def tab(name, route, label)
            a(class: "perf-tab", href: path(route, range: @range), aria: { current: current(name) }) { t(label) }
          end
        end
      end
    end
  end
end

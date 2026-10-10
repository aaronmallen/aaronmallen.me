# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class RangeSwitch < Component
          RANGES = {
            "7" => "ui.components.analytics.ranges.7",
            "14" => "ui.components.analytics.ranges.14",
            "30" => "ui.components.analytics.ranges.30",
          }.freeze

          prop :action, Blog::Types::String
          prop :range, Blog::Types::AnalyticsRange

          def view_template
            FilterSwitch(action: @action, name: "range", options: RANGES, selected: @range.to_s, label: t(".label"))
          end
        end
      end
    end
  end
end

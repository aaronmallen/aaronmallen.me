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
          prop :keep, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

          def view_template
            FilterSwitch(
              action: @action, name: "range", options: RANGES.transform_values { t(it) }, selected: @range.to_s,
              label: t(".label"), keep: @keep,
            )
          end
        end
      end
    end
  end
end

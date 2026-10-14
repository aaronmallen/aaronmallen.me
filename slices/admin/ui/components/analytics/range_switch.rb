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
            AutoForm(action: @action) do
              @keep.each { |name, value| input(type: "hidden", name:, value:) }
              SegmentedControl(label: t(".label"), name: "range", options:, selected: @range.to_s)
            end
          end

          private

          def options = RANGES.transform_values { t(it) }
        end
      end
    end
  end
end

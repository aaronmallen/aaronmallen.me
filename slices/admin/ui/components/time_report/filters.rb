# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TimeReport
        class Filters < Component
          GROUPINGS = Blog::Types::TimeGrouping.values.to_h { [it, ".groupings.#{it}"] }.freeze
          RANGES = Blog::Types::RangePreset.values

          prop :by, Blog::Types::TimeGrouping
          prop :from, Blog::Types::Date
          prop :to, Blog::Types::Date
          prop :today, Blog::Types::Date

          def view_template
            div(class: "time-bar") do
              RangePresets(ranges: RANGES, today: @today, from: @from, to: @to) do |presets|
                presets.href { path(:admin_time, from: it.begin.iso8601, to: it.end.iso8601, by: @by) }
              end
              filter_form
            end
          end

          private

          def filter_form
            AutoForm(action: path(:admin_time), class: "time-bar-form") do
              DateRange(from: @from, to: @to, id_prefix: "time")
              grouping
            end
          end

          def grouping
            Field(label: t(".by")) do
              SegmentedControl(
                label: t(".by"), name: "by", options: GROUPINGS.transform_values { t(it) }, selected: @by,
              )
            end
          end
        end
      end
    end
  end
end

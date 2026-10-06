# frozen_string_literal: true

module Admin
  module UI
    module Components
      module TimeReport
        class Filters < Component
          GROUPINGS = Blog::Types::TimeGrouping.values.to_h { [it, ".groupings.#{it}"] }.freeze

          prop :by, Blog::Types::TimeGrouping
          prop :from, Blog::Types::Date
          prop :to, Blog::Types::Date
          prop :today, Blog::Types::Date

          def view_template
            div(class: "time-rail") do
              Card do
                div(class: "form-stack") do
                  presets
                  filter_form
                end
              end
            end
          end

          private

          def dates
            Field(label: t(".from"), id: "time-from") do |control|
              Input(**control, type: "date", name: "from", value: @from.iso8601, max: @to.iso8601)
            end
            Field(label: t(".to"), id: "time-to") do |control|
              Input(**control, type: "date", name: "to", value: @to.iso8601, min: @from.iso8601)
            end
          end

          def filter_form
            AutoForm(action: path(:admin_time)) do
              div(class: "form-stack") do
                grouping
                dates
              end
            end
          end

          def grouping
            Field(label: t(".by")) do
              SegmentedControl(
                label: t(".by"), name: "by", options: GROUPINGS.transform_values { t(it) }, selected: @by,
              )
            end
          end

          def preset(days)
            current = @to == @today && @from == @today - (days - 1)
            href = path(:admin_time, from: (@today - (days - 1)).iso8601, to: @today.iso8601, by: @by)

            { href:, text: t(".preset", count: days), current: }
          end

          def presets
            Field(label: t(".range")) do
              SegmentedLinks(label: t(".range"), items: Blog::Constants::TIME_RANGES.map { preset(it) })
            end
          end
        end
      end
    end
  end
end

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
            Field(label: t(".from"), id: "time-from") do
              Input(type: "date", id: "time-from", name: "from", value: @from.iso8601, max: @to.iso8601)
            end
            Field(label: t(".to"), id: "time-to") do
              Input(type: "date", id: "time-to", name: "to", value: @to.iso8601, min: @from.iso8601)
            end
          end

          def filter_form
            form(action: path(:admin_time), method: "get", data: { autosubmit: "" }) do
              div(class: "form-stack") do
                grouping
                dates
                noscript { Button(type: "submit", small: true) { t(".apply") } }
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

            a(class: ["seg-option", ("current" if current)], href:, aria: { current: ("true" if current) }) do
              t(".preset", count: days)
            end
          end

          def presets
            Field(label: t(".range")) do
              div(class: "seg", role: "group", aria: { label: t(".range") }) do
                Blog::Constants::TIME_RANGES.each { preset(it) }
              end
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class HourGridCard < Component
          HOUR = "%02d"
          WEEKDAYS = {
            ".days.monday.name" => ".days.monday.short",
            ".days.tuesday.name" => ".days.tuesday.short",
            ".days.wednesday.name" => ".days.wednesday.short",
            ".days.thursday.name" => ".days.thursday.short",
            ".days.friday.name" => ".days.friday.short",
            ".days.saturday.name" => ".days.saturday.short",
            ".days.sunday.name" => ".days.sunday.short",
          }.freeze

          prop :days, Blog::Types::Integer
          prop :hours, Blog::Types::Array.of(Blog::Types::Array.of(Blog::Types::Integer))

          def view_template
            Card(title: t(".title")) do |card|
              card.side { span(class: "chart-peak") { t(".window", count: @days) } }

              div(class: "tbl-scroll") do
                table(class: "heat") do
                  caption(class: "sr-only") { t(".caption", count: @days) }
                  head
                  tbody { @hours.each_with_index { |counts, hour| row(hour, counts) } }
                end
              end
            end
          end

          private

          def cell(count)
            td(class: "heat-cell", style: "--heat: #{Blog::Figures.share(count, peak)}%") do
              span(class: "sr-only") { t(".readers", count:, formatted: Blog::Figures.count(count)) }
            end
          end

          def head
            thead do
              tr do
                td
                WEEKDAYS.each { |name, short| th(class: "heat-day", scope: "col", abbr: t(name)) { t(short) } }
              end
            end
          end

          def peak = @peak ||= @hours.flatten.max.to_i

          def row(hour, counts)
            tr do
              th(class: "heat-hour", scope: "row") { format(HOUR, hour) }
              counts.each { cell(it) }
            end
          end
        end
      end
    end
  end
end

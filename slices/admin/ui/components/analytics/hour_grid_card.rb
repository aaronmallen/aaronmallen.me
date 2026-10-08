# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class HourGridCard < Component
          AXIS = [0, 12, 23].freeze
          HOUR = "%02d"
          WEEKDAYS = {
            ".days.monday.name" => ".days.monday.short",
            ".days.tuesday.name" => ".days.tuesday.short",
            ".days.wednesday.name" => ".days.wednesday.short",
            ".days.thursday.name" => ".days.thursday.short",
            ".days.friday.name" => ".days.friday.short",
            ".days.saturday.name" => ".days.saturday.short",
            ".days.sunday.name" => ".days.sunday.short",
          }.to_a.freeze

          prop :days, Blog::Types::Integer
          prop :hours, Blog::Types::Array.of(Blog::Types::Array.of(Blog::Types::Integer))

          def view_template
            Card(title: t(".title")) do |card|
              card.side { span(class: "chart-peak") { t(".window", count: @days) } }

              grid
              div(class: "heat-axis", aria: { hidden: "true" }) { AXIS.each { |number| span { hour(number) } } }
            end
          end

          private

          def cell(count)
            td(class: "heat-cell", style: "--heat: #{Blog::Helpers::Figures.share(count, peak)}%") do
              span(class: "sr-only") { t(".readers", count:, formatted: Blog::Helpers::Figures.count(count)) }
            end
          end

          def grid
            div(class: "tbl-scroll") do
              table(class: "heat") do
                caption(class: "sr-only") { t(".caption", count: @days) }
                head
                tbody { @hours.transpose.each_with_index { |counts, day| row(day, counts) } }
              end
            end
          end

          def head
            thead do
              tr do
                td
                @hours.size.times { |number| hour_heading(number) }
              end
            end
          end

          def hour(number) = format(HOUR, number)

          def hour_heading(number)
            th(class: "heat-hour", scope: "col") { span(class: "sr-only") { hour(number) } }
          end

          def peak = @peak ||= @hours.flatten.max.to_i

          def row(day, counts)
            name, short = WEEKDAYS.fetch(day)

            tr do
              th(class: "heat-day", scope: "row", abbr: t(name)) { t(short) }
              counts.each { cell(it) }
            end
          end
        end
      end
    end
  end
end

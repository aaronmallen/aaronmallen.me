# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Activity
        class Day < Component
          prop :date, Blog::Types::Date
          prop :events, Blog::Types::Array.of(Blog::Types::Instance(Structs::ActivityEvent))
          prop :today, Blog::Types::Date
          prop :health, Blog::Types::Instance(ROM::Struct).optional, default: nil

          def view_template
            section(class: "activity-day") do
              DayHead(date: @date, today: @today, count: @events.size, sunk: true)
              if @health
                p(class: "activity-health", aria: { label: t(".health") }) do
                  HealthFigures(day: @health, steps: true)
                end
              end
              div(class: "activity-events") { @events.each { Event(event: it) } }
            end
          end
        end
      end
    end
  end
end

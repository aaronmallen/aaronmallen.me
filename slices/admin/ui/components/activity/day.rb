# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Activity
        class Day < Component
          prop :date, Blog::Types::Date
          prop :events, Blog::Types::Array.of(Blog::Types::Instance(Structs::ActivityEvent))
          prop :today, Blog::Types::Date

          def view_template
            section(class: "activity-day") do
              DayHead(date: @date, today: @today, count: @events.size)
              @events.each { Event(event: it) }
            end
          end
        end
      end
    end
  end
end

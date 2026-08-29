# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Activity
        class Day < Component
          SEPARATOR = " · "

          prop :date, Blog::Types::Date
          prop :events, Blog::Types::Array.of(Blog::Types::Instance(Structs::ActivityEvent))
          prop :today, Blog::Types::Date

          def view_template
            section(class: "activity-day") do
              h2(class: "activity-day-head") do
                time(class: "activity-day-date", datetime: @date.iso8601) { l(@date, format: :full) }
                span(class: "activity-day-rule", aria: { hidden: "true" })
                span(class: "activity-day-count") { count }
              end
              @events.each { Event(event: it) }
            end
          end

          private

          def ago
            case days_ago
            when 0 then t(".today")
            when 1 then t(".yesterday")
            else t(".days_ago", count: days_ago) if days_ago.positive?
            end
          end

          def count = [ago, @events.size.to_s].compact.join(SEPARATOR)

          def days_ago = (@today - @date).to_i
        end
      end
    end
  end
end

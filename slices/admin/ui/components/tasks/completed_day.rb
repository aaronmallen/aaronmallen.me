# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class CompletedDay < Component
          COMPLETED = Blog::Types::TaskTab["completed"]

          prop :date, Blog::Types::Date
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :today, Blog::Types::Date

          def view_template
            section(class: "task-day") do
              DayHead(date: @date, today: @today, count: @tasks.size, format: :long, sunk: true)
              @tasks.each { row(it) }
            end
          end

          private

          def row(task)
            Row(task:, filter: COMPLETED, today: @today, ordered: false, scheduled: task.sprint&.sprint_date)
          end
        end
      end
    end
  end
end

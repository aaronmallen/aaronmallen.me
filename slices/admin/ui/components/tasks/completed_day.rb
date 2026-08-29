# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class CompletedDay < Component
          COMPLETED = Blog::Types::TaskTab["completed"]
          SEPARATOR = " · "

          prop :date, Blog::Types::Date
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :today, Blog::Types::Date
          prop :types, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :editing, Blog::Types::Hash.optional, default: nil
          prop :linking, Blog::Types::Hash.optional, default: nil

          def view_template
            section(class: "task-day") do
              h2(class: "task-day-head") do
                time(class: "task-day-date", datetime: @date.iso8601) { l(@date, format: :long) }
                span(class: "task-day-rule", aria: { hidden: "true" })
                span(class: "task-day-count") { count }
              end
              @tasks.each { row(it) }
            end
          end

          private

          def ago
            case days_ago
            when 0 then t(".today")
            when 1 then t(".yesterday")
            else t(".days_ago", count: days_ago)
            end
          end

          def count = [ago, @tasks.size.to_s].join(SEPARATOR)

          def days_ago = (@today - @date).to_i

          def row(task)
            Row(
              task:, filter: COMPLETED, today: @today, types: @types, editing: @editing, linking: @linking,
              ordered: false, scheduled: task.sprint&.sprint_date,
            )
          end
        end
      end
    end
  end
end

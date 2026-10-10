# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Facts < Component
          CREDIT_SEPARATOR = ", "

          prop :task, Blog::Types::Instance(ROM::Struct)

          def view_template
            dl(class: "task-facts") { values.each { |key, value| fact(key, value) } }
          end

          private

          def credit(credit) = credit[:agent] ? t(".agent", **credit.slice(:agent, :model)) : t(".owner")

          def credits = @task.credits.map { credit(it) }.join(CREDIT_SEPARATOR)

          def fact(label_key, value)
            div(class: "task-fact") do
              dt { t(label_key) }
              dd { value.is_a?(Time) ? Moment(at: value) : plain(value) }
            end
          end

          def sprint_day = @task.sprint ? l(@task.sprint.sprint_date, format: :medium) : t(".unscheduled")

          def values
            {
              ".created" => @task.created_at,
              ".updated" => @task.updated_at,
              ".completed" => @task.completed_at,
              ".sprint" => sprint_day,
              ".carried" => t(".carried_count", count: @task.carried_count),
              ".worked" => Blog::Helpers::Figures.hours(@task.worked_seconds),
              ".contributors" => credits,
            }.compact
          end
        end
      end
    end
  end
end

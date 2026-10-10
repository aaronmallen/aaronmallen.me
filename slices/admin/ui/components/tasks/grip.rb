# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Grip < Component
          KEYS = "Alt+ArrowUp Alt+ArrowDown"

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :lead, Blog::Types::Integer.optional, default: nil

          def view_template
            Button(
              small: true, class: "task-grip", hidden: true, label:, aria:, data:,
              icon: "fa-solid fa-grip-vertical",
            )
          end

          private

          def aria = { keyshortcuts: KEYS }

          def data
            {
              task_grip: path(:admin_place_task, id: @task.id), task_token: csrf_token, task_lead: @lead,
              task_failed: t(".failed"),
            }
          end

          def label = t(".label", task: @task.title)
        end
      end
    end
  end
end

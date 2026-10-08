# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class TotalForm < Component
          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :totaling, Blog::Types::Hash
          prop :tab, Blog::Types::String
          prop :origin, Blog::Types::String

          def view_template
            details(class: "task-total-edit", open: @totaling.key?(:errors)) do
              summary(class: "bt sm") { t(".set") }
              Form(action: path(:admin_update_task_total, id: @task.id)) do
                input(type: "hidden", name: "filter", value: @tab)
                input(type: "hidden", name: "origin", value: @origin)
                Hint { t(".hint") }
                WorkedFields(name: "total", scope: "task-#{@task.id}-total", seconds: @task.worked_seconds, **state)
                Button(variant: :pri, type: "submit", small: true) { t(".save") }
              end
            end
          end

          private

          def state = @totaling.slice(:values, :errors)
        end
      end
    end
  end
end

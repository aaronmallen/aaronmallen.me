# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class CompleteForm < Component
          KEY = "x"

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :origin, Blog::Types::String
          prop :compact, Blog::Types::Bool, default: false
          prop :keyed, Blog::Types::Bool, default: false

          def view_template
            Form(action: path(:admin_complete_task, id: @task.id), data: { task_act: "complete" }) do
              HiddenFields(values: { filter: @filter, origin: @origin })
              details(class: "task-complete") do
                toggle
                div(class: "task-complete-panel") do
                  worked_fields
                  Button(type: "submit", variant: :pri, small: true) { done_label }
                end
              end
            end
          end

          private

          def done_label
            IconLabel(icon: "fa-solid fa-check") { t(".complete") }
          end

          def key(**aria)
            return { aria: } unless @keyed

            { aria: { **aria, keyshortcuts: KEY }, data: { key: KEY, key_label: t(".key") } }
          end

          def toggle
            return summary(class: "bt pri sm", **key) { done_label } unless @compact

            label = t(".complete")
            summary(class: "bt sm", title: label, **key(label:)) do
              Icon("fa-solid fa-check")
              span(class: "sr-only") { label }
            end
          end

          def worked_fields
            tracked = @task.tracked_seconds

            input(type: "hidden", name: "worked[tracked]", value: tracked)
            fieldset(class: "task-complete-ask") do
              legend { t(".ask") }
              WorkedFields(name: "worked", scope: "task-#{@task.id}-worked", seconds: tracked)
            end
          end
        end
      end
    end
  end
end

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
          prop :return_to, Blog::Types::String.optional, default: nil

          def view_template
            Form(action: path(:admin_complete_task, id: @task.id), data: { morph: true, task_act: "complete" }) do
              HiddenFields(values: { filter: @filter, origin: @origin, return_to: @return_to })
              tracked? ? toggle(type: "submit") : ask
            end
          end

          private

          def ask
            details(class: "task-complete") do
              toggle(summary: true)
              div(class: "task-complete-panel") do
                worked_fields
                Button(type: "submit", variant: :pri, small: true) { done_label }
              end
            end
          end

          def done_label
            IconLabel(icon: "fa-solid fa-check") { t(".complete") }
          end

          def key(**aria)
            return { aria: } unless @keyed

            { aria: { **aria, keyshortcuts: KEY }, data: { key: KEY, key_label: t(".key") } }
          end

          def toggle(**)
            return Button(**, small: true, variant: :pri, **key) { done_label } unless @compact

            label = t(".complete")
            Button(**, small: true, title: label, **key(label:)) do
              Icon("fa-solid fa-check")
              span(class: "sr-only") { label }
            end
          end

          def tracked? = !@task.running_session.nil? || @task.tracked_seconds.positive?

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

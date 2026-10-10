# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Row < Component
          EDIT = "e"
          ORIGIN = Blog::Types::TaskOrigin["tasks"]

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :today, Blog::Types::Date
          prop :lead, Blog::Types::Integer.optional, default: nil
          prop :ordered, Blog::Types::Bool, default: true
          prop :origin, Blog::Types::String, default: ORIGIN
          prop :scheduled, Blog::Types::Date.optional, default: nil
          prop :tab, Blog::Types::String.optional, default: nil
          prop :bulk, Blog::Types::String.optional, default: nil
          prop :large, Blog::Types::Bool, default: false

          def view_template
            div(class: classes, data: { key_row: true, **order }) do
              @bulk ? pick : box
              RecordKey(kind: "task", id: @task.id)
              div(class: "task-body") do
                task_title
                Meta(task: @task, scheduled: (@scheduled if waiting?))
              end
              side
            end
          end

          private

          def box
            route, label = @task.closed? ? [:admin_reopen_task, reopen_label] : [:admin_complete_task, complete_label]

            Form(action: path(route, id: @task.id)) do
              HiddenFields(values: { filter: @filter, origin: @origin })
              button(type: "submit", class: "task-box", title: label, aria: { label: }) do
                Icon(@task.canceled? ? "fa-solid fa-xmark" : "fa-solid fa-check")
              end
            end
          end

          def classes
            [
              "task", ("large" if @large), ("done" if @task.closed?), ("canceled" if @task.canceled?),
              ("doing" if @task.in_progress?),
            ]
          end

          def complete_label = t("ui.components.tasks.complete_form.complete")

          def edit
            href = path(:admin_edit_task, id: @task.id, filter: tab, origin: @origin)
            label = t(".edit")

            aria = { keyshortcuts: EDIT }
            data = { task_open_edit: true, key: EDIT, key_label: t(".edit_key") }

            Button(href:, label:, aria:, data:, small: true, icon: "fa-regular fa-pen-to-square")
          end

          def order
            return Blog::Constants::EMPTY_HASH unless ordered?

            { task_id: @task.id, task_order: @task.list || @task.sprint_id }
          end

          def ordered? = @ordered && !@task.closed?

          def pick
            BulkCheck(form: @bulk, value: @task.id, label: t(".pick", task: @task.title), class: "task-pick")
          end

          def reopen_label = t("ui.components.tasks.controls.reopen")

          def side
            div(class: "task-acts hov") do
              Grip(task: @task, lead: @lead) if ordered?
              Controls(task: @task, filter: @filter, origin: @origin, row: true) unless @task.closed?
              edit
            end
          end

          def tab = @tab || @filter

          def task_title
            href = path(:admin_task, id: @task.id, filter: tab, origin: @origin)

            a(class: "task-title", href:, data: { task_open: true, key_open: true }) do
              @task.title
            end
          end

          def waiting? = !@scheduled.nil? && @scheduled > @today && !@task.closed?
        end
      end
    end
  end
end

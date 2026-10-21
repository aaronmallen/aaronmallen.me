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
          prop :return_to, Blog::Types::String.optional, default: nil
          prop :project_id, Blog::Types::Integer.optional, default: nil

          def view_template
            div(class: classes, data: { key_row: true, menu: menu_path, **order }) do
              pick if @bulk
              RecordKey(kind: "task", label: @task.label)
              div(class: "task-body") do
                task_title
                Meta(task: @task, scheduled: (@scheduled if waiting?))
              end
              side
            end
          end

          private

          def classes
            ["task", ("done" if @task.closed?), ("canceled" if @task.canceled?), ("doing" if @task.in_progress?)]
          end

          def edit
            href = path(:admin_edit_task, id: @task.id, filter: tab, origin: @origin)
            label = t(".edit")

            aria = { keyshortcuts: EDIT }
            data = { task_open_edit: true, key: EDIT, key_label: t(".edit_key") }

            Button(href:, label:, aria:, data:, small: true, icon: :edit)
          end

          def menu_path = path(:admin_task_menu, id: @task.id, filter: tab, origin: @origin, project: @project_id)

          def order
            return Blog::Constants::EMPTY_HASH unless ordered?

            { task_id: @task.id, task_order: @task.list || @task.sprint_id }
          end

          def ordered? = @ordered && !@task.closed?

          def pick
            BulkCheck(form: @bulk, value: @task.id, label: t(".pick", task: @task.title), class: "task-pick")
          end

          def side
            div(class: "task-acts hov") do
              Grip(task: @task, lead: @lead) if ordered?
              Controls(task: @task, filter: @filter, origin: @origin, row: true, ahead: waiting?, return_to: @return_to)
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

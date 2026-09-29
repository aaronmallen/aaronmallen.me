# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class Edit < View
          include Components::Tasks

          PREFIX = "#"
          TAG_SEPARATOR = ", "

          def initialize(task:, errors:, values:, filter:, origin:)
            super()
            @task = task
            @errors = errors
            @values = values || stored
            @returns = { filter:, origin: }
          end

          def view_template
            PageHead(title: @task.title, sub: t(".sub", key:)) { back }

            Card(label: t(".label"), title: t(".title")) do
              div(class: "task-edit", data: { task_edit: @task.id }) do
                TaskForm(
                  errors: @errors, returns: @returns, scope:, task: @task, today: Blog::TimeZone.today,
                  values: @values, autofocus: true,
                ) { foot }
                delete_form
              end
            end
          end

          private

          def back
            a(class: "btn", href: task_path) do
              i(class: "fa-solid fa-arrow-left", aria: { hidden: "true" })
              span { t(".back") }
            end
          end

          def delete_form
            Form(
              action: path(:admin_delete_task, id: @task.id), id: delete_id,
              data: { confirm: t(".confirm_delete", task: @task.title) },
            ) do
              @returns.each { |name, value| input(type: "hidden", name:, value:) }
            end
          end

          def delete_id = "task-#{@task.id}-delete"

          def foot
            Button(variant: :warn, type: "submit", small: true, form: delete_id, class: "task-form-delete") do
              i(class: "fa-regular fa-trash-can", aria: { hidden: "true" })
              span { t(".delete") }
            end
            a(class: "btn sm gh", href: task_path, data: { task_close: true }) { t(".cancel") }
          end

          def key = PREFIX + @task.id.to_s

          def scope = "task-#{@task.id}"

          def stored
            {
              list: @task.place,
              note: @task.note.to_s,
              sprint_on: @task.sprint&.sprint_date&.iso8601,
              tags: @task.tags.map(&:name).join(TAG_SEPARATOR),
              title: @task.title,
            }
          end

          def task_path = path(:admin_task, id: @task.id, **@returns)
        end
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class Edit < View
          include Components::Tasks

          TAG_SEPARATOR = ", "

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :errors, Blog::Types::Hash
          prop(:values, Blog::Types::Hash) { it || stored }
          prop :filter, Blog::Types::String
          prop :origin, Blog::Types::TaskOrigin

          def view_template
            PageHead(title: @task.title, sub: t(".sub", key:)) { back }

            Card(label: t(".label"), title: t(".title")) do
              div(class: "task-edit", data: { task_edit: @task.id }) do
                TaskForm(
                  errors: @errors, returns:, scope:, task: @task, today: Blog::TimeZone.today,
                  values: @values, autofocus: true,
                ) { foot }
                delete_form
              end
            end
          end

          private

          def back
            BackLink(href: task_path) { t(".back") }
          end

          def delete_form
            Form(
              action: path(:admin_delete_task, id: @task.id), id: delete_id,
              data: { confirm: t(".confirm_delete", task: @task.title) },
            ) do
              HiddenFields(values: returns)
            end
          end

          def delete_id = "task-#{@task.id}-delete"

          def foot
            Button(
              variant: :warn, type: "submit", small: true, form: delete_id, class: "task-form-delete",
              icon: "fa-regular fa-trash-can",
            ) do
              t(".delete")
            end
            Button(href: task_path, data: { task_close: true }, small: true, variant: :gh) { t(".cancel") }
          end

          def key = Components::RecordKey.key(@task.id)

          def returns = { filter: @filter, origin: @origin }

          def scope = "task-#{@task.id}"

          def stored
            {
              contributors: @task.credits,
              list: @task.place,
              note: @task.note.to_s,
              sprint_on: @task.sprint&.sprint_date&.iso8601,
              tags: @task.tags.map(&:name).join(TAG_SEPARATOR),
              title: @task.title,
            }
          end

          def task_path = path(:admin_task, id: @task.id, **returns)
        end
      end
    end
  end
end

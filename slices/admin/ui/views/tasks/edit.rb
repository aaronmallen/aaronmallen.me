# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class Edit < View
          include Components::Tasks

          CANCEL = { task_open: true, task_cancel: true }.freeze
          LIVE_TABLES = %w[
            projects record_links sprints task_comments task_contributors task_events task_links task_series task_tags
            work_sessions
          ].freeze

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :timeline, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :forms, Blog::Types::Hash
          prop :linking, Blog::Types::Hash
          prop :errors, Blog::Types::Hash
          prop :series, Blog::Types::Instance(ROM::Struct).optional, default: nil
          prop(:values, Blog::Types::Hash) { it || stored }
          prop :filter, Blog::Types::String
          prop :origin, Blog::Types::TaskOrigin

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            article(class: "task-drawer", data: { task_edit: @task.id }) do
              DrawerHead(task: @task, filter: @filter, origin: @origin)
              div(class: "task-drawer-body") { body }
              footer(class: "task-drawer-foot") { foot }
            end
          end

          private

          def body
            h1(class: "sr-only") { @task.title }
            TaskForm(
              errors: @errors, returns:, scope:, task: @task, today: Blog::TimeZone.today, values: @values,
              autofocus: true, bare: true,
            )
            TimeWorked(task: @task, entries: @timeline, forms: @forms, tab: @filter, origin: @origin)
            LinkEditor(
              task: @task, tab: @filter, origin: @origin, linking: @linking,
              find_path: path(:admin_edit_task, id: @task.id, **returns),
            )
          end

          def delete
            DeleteForm(
              action: path(:admin_delete_task, id: @task.id), class: "task-drawer-delete",
              confirm: t(".confirm_delete", task: @task.title), label: t(".delete"),
            ) { HiddenFields(values: returns) }
          end

          def foot
            delete
            Button(href: path(:admin_task, id: @task.id, **returns), data: CANCEL, small: true, variant: :gh) do
              t(".cancel")
            end
            Button(
              variant: :pri, type: "submit", small: true, form: "task-#{@task.id}-form",
              icon: :save,
            ) { t(".save") }
          end

          def returns = { filter: @filter, origin: @origin }

          def scope = "task-#{@task.id}"

          def stored
            {
              contributors: @task.credits,
              list: @task.place,
              note: @task.note.to_s,
              recur: @series.to_h,
              sprint_on: @task.sprint&.sprint_date&.iso8601,
              tags: Blog::Types::TagField[@task.tags],
              title: @task.title,
            }
          end
        end
      end
    end
  end
end

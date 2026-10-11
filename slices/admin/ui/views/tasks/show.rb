# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Tasks
        class Show < View
          include Components::Tasks

          CLOSE = { task_close: true }.freeze
          EDIT = "e"

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :note_html, Blog::Types::String.optional
          prop :linking, Blog::Types::Hash
          prop :records, Blog::Types::Hash
          prop :timeline, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :edited, Blog::Types::Array.of(Blog::Types::Integer)
          prop :forms, Blog::Types::Hash
          prop :filter, Blog::Types::String
          prop :origin, Blog::Types::TaskOrigin

          def view_template
            article(class: "task-drawer", data: { task_read: @task.id }) do
              DrawerHead(task: @task, filter: @filter, origin: @origin)
              div(class: "task-drawer-body") { body }
              footer(class: "task-drawer-foot") { foot }
            end
          end

          private

          def body
            content_for(:title, @task.title)
            status_bar
            h1(class: "task-read-title") { @task.title }
            note
            Facts(task: @task)
            TimeWorked(task: @task, entries: @timeline, forms: @forms, tab: @filter, origin: @origin)
            links
            linked
            Comments(task: @task, entries: @timeline, edited: @edited, forms: @forms, tab: @filter, origin: @origin)
            Timeline(entries: @timeline)
          end

          def close(&) = OriginLink(origin: @origin, filter: @filter, variant: :gh, small: true, data: CLOSE, &)

          def delete
            Form(
              action: path(:admin_delete_task, id: @task.id), class: "task-drawer-delete",
              data: { confirm: t(".confirm_delete", key:) },
            ) do
              HiddenFields(values: { filter: @filter, origin: @origin })
              Button(variant: :warn, type: "submit", small: true, icon: "fa-regular fa-trash-can") { t(".delete") }
            end
          end

          def edit
            data = { task_open_edit: true, key: EDIT, key_label: t(".edit_key") }

            Button(
              href: edit_path, small: true, icon: "fa-regular fa-pen-to-square", title: t(".edit_title"),
              aria: { keyshortcuts: EDIT }, data:,
            ) { t(".edit") }
          end

          def edit_path = path(:admin_edit_task, id: @task.id, filter: @filter, origin: @origin)

          def foot
            delete
            close { t(".close") }
            edit
          end

          def key = Components::RecordKey.key(@task.id)

          def linked
            RecordLinks::Section(
              records: @records, kind: "task", id: @task.id, fields: { filter: @filter, origin: @origin },
              find_path: path(:admin_task, id: @task.id), card: false,
            )
          end

          def links = LinkEditor(task: @task, tab: @filter, origin: @origin, linking: @linking)

          def note
            Field(label: t(".notes")) do
              next div(class: "markdown-body post-body") { raw(safe(@note_html)) } if @note_html

              Hint(class: "task-read-empty") do
                plain t(".no_notes")
                whitespace
                a(href: edit_path, data: { task_open_edit: true }) { t(".add_notes") }
              end
            end
          end

          def status_bar
            div(class: "task-stbar") do
              Controls(task: @task, filter: @filter, origin: @origin, moves: false)
              p(class: "task-stbar-worked") do
                Icon("fa-regular fa-clock")
                plain t(".worked_total", span: Blog::Helpers::Figures.hours(@task.tracked_seconds))
                span(class: "task-stbar-running") { t(".running") } if @task.running_session
              end
            end
          end
        end
      end
    end
  end
end

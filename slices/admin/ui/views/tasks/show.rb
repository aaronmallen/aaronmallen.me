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
          prop :forms, Blog::Types::Hash
          prop :filter, Blog::Types::String
          prop :origin, Blog::Types::TaskOrigin

          def view_template
            article(class: "task-drawer", data: { task_read: @task.id }) do
              header(class: "task-drawer-head") { meta }
              div(class: "task-drawer-body") { body }
              footer(class: "task-drawer-foot") { foot }
            end
          end

          private

          def body
            PageHead(title: @task.title, kicker:)
            status_bar
            note
            facts
            links
            linked
            Timeline(task: @task, entries: @timeline, forms: @forms, tab: @filter, origin: @origin)
          end

          def close(**, &) = OriginLink(origin: @origin, filter: @filter, variant: :gh, small: true, data: CLOSE, **, &)

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
            href = path(:admin_edit_task, id: @task.id, filter: @filter, origin: @origin)
            data = { task_open_edit: true, key: EDIT, key_label: t(".edit_key") }

            Button(
              href:, small: true, icon: "fa-regular fa-pen-to-square", title: t(".edit_title"),
              aria: { keyshortcuts: EDIT }, data:,
            ) { t(".edit") }
          end

          def facts
            Facts(task: @task)
            TotalForm(task: @task, totaling: @forms[:totaling], tab: @filter, origin: @origin)
          end

          def foot
            delete
            close { t(".close") }
            edit
          end

          def key = Components::RecordKey.key(@task.id)

          def kicker = dotted(key, reference)

          def linked
            RecordLinks::Section(
              records: @records, kind: "task", id: @task.id, fields: { filter: @filter, origin: @origin },
              find_path: path(:admin_task, id: @task.id),
            )
          end

          def links
            Card(label: t(".related"), title: t(".links")) do
              LinkEditor(task: @task, tab: @filter, origin: @origin, linking: @linking)
            end
          end

          def meta
            RecordKey(kind: "task", id: @task.id)
            Status(status: @task.status)
            span(class: "read-meta-list") { t(Helpers::TaskLists.name(@task.place)) }
            SourceLink(source: @task.source)
            @task.tags.each { Tag(tag: it) }
            label = t(".close")
            close(label:, icon: "fa-solid fa-xmark", class: "task-drawer-close") { label }
          end

          def note
            return unless @note_html

            Card(label: t(".note_label"), title: t(".note")) do
              div(class: "markdown-body post-body") { raw(safe(@note_html)) }
            end
          end

          def reference = @task.source && ::Tasks::Structs::SourceReference.for(@task.source).key

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

# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Timeline < Component
          ROUTES = {
            create: :admin_create_task_comment, update: :admin_update_task_comment,
            delete: :admin_delete_task_comment,
          }.freeze

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :forms, Blog::Types::Hash
          prop :tab, Blog::Types::String
          prop :origin, Blog::Types::String

          def view_template
            Card(label: t(".label"), title: t(".title"), class: "timeline-card") do
              Hint { t(".empty") } if @entries.empty?
              thread
            end
          end

          private

          def author(comment)
            Icon(SourceLink::ICONS.fetch(comment.provider))
            plain(comment.author || t(".unknown_author"))
          end

          def return_fields
            input(type: "hidden", name: "filter", value: @tab)
            input(type: "hidden", name: "origin", value: @origin)
          end

          def session_acts(entry)
            SessionActs(task: @task, entry:, timing: @forms[:timing], tab: @tab, origin: @origin) if entry.session?
          end

          def source(comment)
            a(class: "task-source", href: comment.url, target: "_blank", rel: "noopener noreferrer") { t(".view") }
          end

          def thread
            CommentThread(
              record_id: @task.id, entries: @entries, routes: ROUTES, scope: "task", form: @forms[:commenting],
              error: FieldError,
            ) do |thread|
              thread.event { |entry| TimelineEvent(entry:) { session_acts(entry) } }
              thread.author { author(it) }
              thread.source { source(it) }
              thread.fields { return_fields }
            end
          end
        end
      end
    end
  end
end

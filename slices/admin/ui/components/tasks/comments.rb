# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Comments < Component
          ROUTES = {
            create: :admin_create_task_comment, update: :admin_update_task_comment,
            delete: :admin_delete_task_comment,
          }.freeze

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :edited, Blog::Types::Array.of(Blog::Types::Integer)
          prop :forms, Blog::Types::Hash
          prop :tab, Blog::Types::String
          prop :origin, Blog::Types::String

          def view_template
            Field(label: t(".label"), class: "task-comments") { thread }
          end

          private

          def author(comment)
            Icon(SourceLink::ICONS.fetch(comment.provider))
            plain(comment.author || t(".unknown_author"))
          end

          def return_fields
            HiddenFields(values: { filter: @tab, origin: @origin })
          end

          def source(comment)
            a(class: "task-source", href: comment.url, **OUTBOUND) { t(".view") }
          end

          def thread
            CommentThread(
              record_id: @task.id, entries: @entries.select(&:comment?), routes: ROUTES, scope: "task",
              form: @forms[:commenting], error: FieldError, edited: @edited,
            ) do |thread|
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

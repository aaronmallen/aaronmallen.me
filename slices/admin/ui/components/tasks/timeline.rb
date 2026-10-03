# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Timeline < Component
          EDITOR_HEIGHT = "120px"
          RENDERER = Blog::Types::MarkdownRenderer["tasks"]

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :commenting, Blog::Types::Hash
          prop :tab, Blog::Types::String
          prop :origin, Blog::Types::String

          def view_template
            Card(label: t(".label"), title: t(".title"), class: "task-activity") do
              @entries.empty? ? Hint { t(".empty") } : ol(class: "task-timeline") { @entries.each { entry(it) } }
              add_form
            end
          end

          private

          def acts(comment)
            div(class: "task-comment-acts") do
              edit_form(comment)
              delete_form(comment)
            end
          end

          def add_form
            Form(action: path(:admin_create_task_comment, id: @task.id), class: "task-comment-form") do
              return_fields
              body_field(nil, t(".add_label"))
              Button(variant: :pri, type: "submit", small: true) { t(".add") }
            end
          end

          def author(comment)
            span(class: "task-comment-author") do
              if comment.synced?
                i(class: SourceLink::ICONS.fetch(comment.provider), aria: { hidden: "true" })
                plain(comment.author || t(".unknown_author"))
              else
                plain(Blog::Owner.full_name)
              end
            end
          end

          def body_field(id, label, saved = nil)
            scope = ["task-#{@task.id}-comment", id].compact.join("-")
            errors = errors_for(id)
            value = mine?(id) ? @commenting[:body] : saved

            Field(label:) do
              MarkdownEditor(**FieldError.control_attributes(:body, errors, scope), **editor_props(label, value))
              FieldError(field: :body, errors:, scope:)
            end
          end

          def comment(comment)
            id = comment.source_id

            li(class: "task-comment", id: "task-comment-#{id}", data: { task_comment: id }) do
              comment_head(comment)
              div(class: "task-body post-body task-comment-body") do
                raw(safe(::Tasks::Markdown.to_html(comment.body).strip))
              end
            end
          end

          def comment_head(comment)
            div(class: "task-comment-head") do
              author(comment)
              moment(comment.occurred_at)
              comment.synced? ? source(comment) : acts(comment)
            end
          end

          def delete_form(comment)
            label = t(".delete")
            data = { confirm: t(".confirm_delete"), confirm_styled: true }

            Form(action: path(:admin_delete_task_comment, id: @task.id, comment_id: comment.source_id), data:) do
              return_fields
              Button(type: "submit", variant: :gh, small: true, title: label, aria: { label: }) do
                i(class: "fa-regular fa-trash-can", aria: { hidden: "true" })
              end
            end
          end

          def edit_form(comment)
            details(class: "task-comment-edit", open: mine?(comment.source_id)) do
              summary(class: "btn sm") { t(".edit") }
              Form(action: path(:admin_update_task_comment, id: @task.id, comment_id: comment.source_id)) do
                return_fields
                body_field(comment.source_id, t(".edit_label"), comment.body)
                Button(variant: :pri, type: "submit", small: true) { t(".save") }
              end
            end
          end

          def editor_props(label, value)
            { name: "comment[body]", value: value.to_s, height: EDITOR_HEIGHT, renderer: RENDERER, label: }
          end

          def entry(entry) = entry.comment? ? comment(entry) : TimelineEvent(entry:)

          def errors_for(id) = mine?(id) ? @commenting[:errors] : Blog::Constants::EMPTY_HASH

          def mine?(id) = @commenting.key?(:id) && @commenting[:id] == id

          def moment(at) = time(class: "task-comment-time", datetime: at.iso8601) { stamp(at) }

          def return_fields
            input(type: "hidden", name: "filter", value: @tab)
            input(type: "hidden", name: "origin", value: @origin)
          end

          def source(comment)
            a(class: "task-source", href: comment.url, target: "_blank", rel: "noopener noreferrer") { t(".view") }
          end

          def stamp(time) = l(Blog::TimeZone.local(time), format: :medium)
        end
      end
    end
  end
end

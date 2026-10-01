# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Comments < Component
          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :comments, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :commenting, Blog::Types::Hash
          prop :tab, Blog::Types::String
          prop :origin, Blog::Types::String

          def view_template
            Card(label: t(".label"), title: t(".title"), class: "task-comments") do
              @comments.empty? ? Hint { t(".empty") } : ol(class: "task-comment-list") { @comments.each { item(it) } }
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

            Field(label:, id: FieldError.id_for(:body, scope)) do
              Textarea(
                **FieldError.control_attributes(:body, errors, scope), name: "comment[body]", rows: 3, value:,
              )
              FieldError(field: :body, errors:, scope:)
            end
          end

          def delete_form(comment)
            label = t(".delete")
            data = { confirm: t(".confirm_delete"), confirm_styled: true }

            Form(action: path(:admin_delete_task_comment, id: @task.id, comment_id: comment.id), data:) do
              return_fields
              Button(type: "submit", variant: :gh, small: true, title: label, aria: { label: }) do
                i(class: "fa-regular fa-trash-can", aria: { hidden: "true" })
              end
            end
          end

          def edit_form(comment)
            details(class: "task-comment-edit", open: mine?(comment.id)) do
              summary(class: "btn sm") { t(".edit") }
              Form(action: path(:admin_update_task_comment, id: @task.id, comment_id: comment.id)) do
                return_fields
                body_field(comment.id, t(".edit_label"), comment.body)
                Button(variant: :pri, type: "submit", small: true) { t(".save") }
              end
            end
          end

          def errors_for(id) = mine?(id) ? @commenting[:errors] : Blog::Constants::EMPTY_HASH

          def head(comment)
            div(class: "task-comment-head") do
              author(comment)
              time(class: "task-comment-time", datetime: comment.created_at.iso8601) { stamp(comment.created_at) }
              comment.synced? ? source(comment) : acts(comment)
            end
          end

          def item(comment)
            li(class: "task-comment", id: "task-comment-#{comment.id}", data: { task_comment: comment.id }) do
              head(comment)
              div(class: "task-body post-body task-comment-body") do
                raw(safe(::Tasks::Markdown.to_html(comment.body).strip))
              end
            end
          end

          def mine?(id) = @commenting.key?(:id) && @commenting[:id] == id

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

# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class Timeline < Component
          EDITOR_HEIGHT = "120px"
          RENDERER = Blog::Types::MarkdownRenderer["tasks"]

          prop :decision, Blog::Types::Instance(ROM::Struct)
          prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :form, Blog::Types::Hash

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
            Form(action: path(:admin_create_decision_comment, id: @decision.id), class: "task-comment-form") do
              body_field(nil, t(".add_label"))
              Button(variant: :pri, type: "submit", small: true) { t(".add") }
            end
          end

          def body_field(id, label, saved = nil)
            scope = ["decision-#{@decision.id}-comment", id].compact.join("-")
            errors = mine?(id) ? @form[:errors] : Blog::Constants::EMPTY_HASH
            value = mine?(id) ? Blog::Types::Text[@form[:params][:body]] : saved

            Field(label:) do
              MarkdownEditor(**FieldError.control_attributes(:body, errors, scope), **editor_props(label, value))
              FieldError(field: :body, errors:, scope:)
            end
          end

          def comment(comment)
            id = comment.source_id

            li(class: "task-comment", id: "decision-comment-#{id}", data: { decision_comment: id }) do
              comment_head(comment)
              div(class: "task-body post-body task-comment-body") do
                raw(safe(::Tasks::Markdown.to_html(comment.body).strip))
              end
            end
          end

          def comment_head(comment)
            div(class: "task-comment-head") do
              span(class: "task-comment-author") { Blog::Owner.full_name }
              time(class: "task-comment-time", datetime: comment.occurred_at.iso8601) { stamp(comment.occurred_at) }
              acts(comment)
            end
          end

          def delete_form(comment)
            label = t(".delete")
            data = { confirm: t(".confirm_delete"), confirm_styled: true }
            action = path(:admin_delete_decision_comment, id: @decision.id, comment_id: comment.source_id)

            Form(action:, data:) do
              Button(type: "submit", variant: :gh, small: true, title: label, aria: { label: }) do
                i(class: "fa-regular fa-trash-can", aria: { hidden: "true" })
              end
            end
          end

          def edit_form(comment)
            details(class: "task-comment-edit", open: mine?(comment.source_id)) do
              summary(class: "btn sm") { t(".edit") }
              Form(action: path(:admin_update_decision_comment, id: @decision.id, comment_id: comment.source_id)) do
                body_field(comment.source_id, t(".edit_label"), comment.body)
                Button(variant: :pri, type: "submit", small: true) { t(".save") }
              end
            end
          end

          def editor_props(label, value)
            { name: "comment[body]", value: value.to_s, height: EDITOR_HEIGHT, renderer: RENDERER, label: }
          end

          def entry(entry) = entry.comment? ? comment(entry) : TimelineEvent(entry:, options:)

          def mine?(id) = @form[:name] == :comment && @form[:id] == id

          def options = @options ||= @decision.options.to_h { [it.id, it.title] }

          def stamp(time) = l(Blog::TimeZone.local(time), format: :medium)
        end
      end
    end
  end
end

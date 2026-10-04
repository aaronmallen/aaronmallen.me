# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class SessionActs < Component
          FIELDS = { started_at: ".started_at", ended_at: ".ended_at" }.freeze

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :entry, Blog::Types::Instance(ROM::Struct)
          prop :timing, Blog::Types::Hash
          prop :tab, Blog::Types::String
          prop :origin, Blog::Types::String

          def view_template
            div(class: "task-comment-acts") do
              edit_form
              delete_form
            end
          end

          private

          def delete_form
            label = t(".delete")
            data = { confirm: t(".confirm_delete"), confirm_styled: true }

            Form(action: route(:admin_delete_task_session), data:) do
              return_fields
              Button(type: "submit", variant: :gh, small: true, title: label, aria: { label: }) do
                i(class: "fa-regular fa-trash-can", aria: { hidden: "true" })
              end
            end
          end

          def edit_form
            details(class: "task-comment-edit", open: mine?) do
              summary(class: "btn sm") { t(".edit") }
              Form(action: route(:admin_update_task_session)) do
                return_fields
                fields.each { |field, label| moment_field(field, label) }
                Button(variant: :pri, type: "submit", small: true) { t(".save") }
              end
            end
          end

          def errors = mine? ? @timing[:errors] : Blog::Constants::EMPTY_HASH

          def fields = @entry.running? ? FIELDS.slice(:started_at) : FIELDS

          def mine? = @timing[:id] == @entry.source_id

          def moment_field(field, label)
            scope = "task-session-#{@entry.source_id}"
            control = FieldError.control_attributes(field, errors, scope)

            Field(label: t(label), id: control[:id]) do
              Input(**control, type: "datetime-local", name: "session[#{field}]", value: value(field))
              FieldError(field:, errors:, scope:)
            end
          end

          def return_fields
            input(type: "hidden", name: "filter", value: @tab)
            input(type: "hidden", name: "origin", value: @origin)
          end

          def route(name) = path(name, id: @task.id, session_id: @entry.source_id)

          def saved(field) = field == :started_at ? @entry.occurred_at : @entry.ended_at

          def value(field) = mine? ? @timing[:values][field].to_s : Blog::TimeZone.input_value(saved(field))
        end
      end
    end
  end
end

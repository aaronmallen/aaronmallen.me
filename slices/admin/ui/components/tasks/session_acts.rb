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
            div(class: "comment-acts") do
              edit_form
              delete_form unless @entry.running?
            end
          end

          private

          def delete_form
            label = t(".delete")
            data = { confirm: t(".confirm_delete") }

            Form(action: route(:admin_delete_task_session), data:) do
              return_fields
              Button(
                type: "submit", variant: :gh, small: true, title: label, aria: { label: },
                icon: "fa-regular fa-trash-can",
              )
            end
          end

          def edit_form
            details(class: "comment-edit", open: mine?) do
              summary(class: "btn sm") { t(".edit") }
              Form(action: route(:admin_update_task_session)) do
                return_fields
                fields.each { |field, label| moment_field(field, label) }
                FieldError(field: :ended_at, errors:, scope: error_scope) if @entry.running?
                Button(variant: :pri, type: "submit", small: true) { t(".save") }
              end
            end
          end

          def error_scope = "task-session-#{@entry.source_id}"

          def errors = mine? ? @timing[:errors] : Blog::Constants::EMPTY_HASH

          def fields = @entry.running? ? FIELDS.slice(:started_at) : FIELDS

          def mine? = @timing[:id] == @entry.source_id

          def moment_field(field, label)
            Field(label: t(label), name: field, errors:, error: FieldError, scope: error_scope) do |control|
              Input(**control, type: "datetime-local", name: "session[#{field}]", value: value(field))
            end
          end

          def return_fields
            input(type: "hidden", name: "filter", value: @tab)
            input(type: "hidden", name: "origin", value: @origin)
          end

          def route(name) = path(name, id: @task.id, session_id: @entry.source_id)

          def saved(field) = field == :started_at ? @entry.occurred_at : @entry.ended_at

          def saved_value(field) = Blog::TimeZone.input_value(saved(field))

          def typed(field) = @timing[:values].fetch(field) { saved_value(field) }.to_s

          def value(field) = mine? ? typed(field) : saved_value(field)
        end
      end
    end
  end
end

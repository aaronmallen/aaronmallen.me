# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class AddSessionForm < Component
          FIELDS = { started_at: ".started_at", ended_at: ".ended_at" }.freeze

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :adding, Blog::Types::Hash
          prop :tab, Blog::Types::String
          prop :origin, Blog::Types::String

          def view_template
            details(class: "task-session-add", open: @adding.key?(:errors)) do
              Button(summary: true, small: true) { t(".add") }
              Form(action: path(:admin_create_task_session, id: @task.id)) do
                HiddenFields(values: { filter: @tab, origin: @origin })
                Hint { t(".hint") }
                FIELDS.each { |field, label| moment_field(field, label) }
                Button(variant: :pri, type: "submit", small: true) { t(".save") }
              end
            end
          end

          private

          def errors = @adding.fetch(:errors, Blog::Constants::EMPTY_HASH)

          def moment_field(field, label)
            Field(label: t(label), name: field, errors:, error: FieldError,
                  scope: "task-#{@task.id}-session") do |control|
              Input(**control, type: "datetime-local", name: "session[#{field}]", value: value(field))
            end
          end

          def value(field) = @adding.fetch(:values, Blog::Constants::EMPTY_HASH)[field].to_s
        end
      end
    end
  end
end

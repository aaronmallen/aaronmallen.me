# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Capture < Component
          NONE = ""

          prop :filter, Blog::Types::String
          prop :types, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :values, Blog::Types::Hash
          prop :errors, Blog::Types::Hash
          prop :autofocus, Blog::Types::Bool, default: true
          prop :origin, Blog::Types::String.optional, default: nil
          prop :scope, Blog::Types::String, default: FieldError::SCOPE
          prop :sprint_on, Blog::Types::String.optional, default: nil
          prop :target, Blog::Types::String.optional, default: nil

          def view_template
            div(class: "task-capture") do
              Form(action: path(:admin_tasks), class: "task-capture-row") do
                hidden_fields
                field
                type_field
                add
              end
              FieldError(field: :title, errors: @errors, scope: @scope)
            end
          end

          private

          def add
            Button(variant: :pri, type: "submit", title: t(".add"), aria: { label: t(".add") }) do
              i(class: "fa-solid fa-plus", aria: { hidden: "true" })
            end
          end

          def field
            label(class: "sr-only", for: FieldError.id_for(:title, @scope)) { t(".label") }
            Input(
              **FieldError.control_attributes(:title, @errors, @scope),
              autocomplete: "off",
              autofocus: @autofocus,
              name: "task[title]",
              placeholder:,
              value: @values[:title],
            )
          end

          def hidden_fields
            input(type: "hidden", name: "filter", value: @filter)
            input(type: "hidden", name: "origin", value: @origin) if @origin
            input(type: "hidden", name: "sprint_on", value: @sprint_on) if @sprint_on
          end

          def placeholder = @target ? t(".into", target: @target) : t(".placeholder")

          def type_field
            id = FieldError.id_for(:task_type_id, @scope)

            label(class: "sr-only", for: id) { t(".type") }
            Select(id:, name: "task[task_type_id]", options: type_options, selected: @values[:task_type_id])
          end

          def type_options = { NONE => t(".no_type") }.merge(@types.to_h { [it.id.to_s, it.name] })
        end
      end
    end
  end
end

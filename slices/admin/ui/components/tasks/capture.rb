# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Capture < Component
          prop :filter, Blog::Types::String
          prop :target, Blog::Types::String
          prop :values, Blog::Types::Hash
          prop :errors, Blog::Types::Hash
          prop :autofocus, Blog::Types::Bool, default: true
          prop :origin, Blog::Types::String.optional, default: nil
          prop :scope, Blog::Types::String, default: FieldError::SCOPE

          def view_template
            div(class: "task-capture") do
              Form(action: path(:admin_tasks), class: "task-capture-row") do
                hidden_fields
                field
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
              placeholder: t(".into", target: @target),
              value: @values[:title],
            )
          end

          def hidden_fields
            input(type: "hidden", name: "filter", value: @filter)
            input(type: "hidden", name: "origin", value: @origin) if @origin
          end
        end
      end
    end
  end
end

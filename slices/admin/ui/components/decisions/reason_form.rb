# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class ReasonForm < Component
          HEIGHT = "120px"
          RENDERER = Blog::Types::MarkdownRenderer["tasks"]

          prop :decision, Blog::Types::Instance(ROM::Struct)
          prop :form, Blog::Types::Hash
          prop :name, Blog::Types::Symbol.enum(:drop, :reopen, :resolve)
          prop :route, Blog::Types::Symbol
          prop :variant, Blog::Types::Symbol

          def view_template(&)
            Form(action: path(@route, id: @decision.id), class: "stack-form") do
              yield if block_given?
              reason_field
              Button(variant: @variant, type: "submit", small: true) { t([".submit", @name].join(".")) }
            end
          end

          private

          def errors = @form[:name] == @name ? @form[:errors] : Blog::Constants::EMPTY_HASH

          def reason_field
            Field(label: t(".reason")) do
              MarkdownEditor(field: :reason, errors:, error: FieldError, scope: "decision-#{@name}", **reason_props)
            end
          end

          def reason_props
            { name: "decision[reason]", value:, height: HEIGHT, renderer: RENDERER, label: t(".reason"),
              placeholder: t([".placeholders", @name].join(".")) }
          end

          def value
            return Blog::Constants::EMPTY_STRING unless @form[:name] == @name

            Blog::Types::Text[@form[:params][:reason]]
          end
        end
      end
    end
  end
end

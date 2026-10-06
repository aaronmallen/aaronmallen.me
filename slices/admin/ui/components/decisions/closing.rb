# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class Closing < Component
          HEIGHT = "120px"
          PLACEHOLDERS = {
            drop: ".placeholders.drop", reopen: ".placeholders.reopen", resolve: ".placeholders.resolve",
          }.freeze
          RENDERER = Blog::Types::MarkdownRenderer["tasks"]

          prop :decision, Blog::Types::Instance(ROM::Struct)
          prop :form, Blog::Types::Hash

          def view_template
            if @decision.open?
              Card(label: t(".label"), title: t(".resolve_title")) { resolve }
              Card(label: t(".label"), title: t(".drop_title")) { drop }
            else
              Card(label: t(".label"), title: t(".reopen_title")) { reopen }
            end
          end

          private

          def choice_field(errors)
            scope = scope_for(:resolve)

            Field(label: t(".option"), name: :option_id, errors:, error: FieldError, scope:) do |control|
              Select(
                **control,
                name: "decision[option_id]",
                options: choices,
                selected: value(:resolve, :option_id),
                required: true,
              )
            end
          end

          def choices
            { Blog::Constants::EMPTY_STRING => t(".pick") }.merge(@decision.options.to_h { [it.id.to_s, it.title] })
          end

          def drop
            Form(action: path(:admin_drop_decision, id: @decision.id), class: "stack-form") do
              reason_field(:drop)
              Button(variant: :warn, type: "submit", small: true) { t(".drop") }
            end
          end

          def errors_for(name) = @form[:name] == name ? @form[:errors] : Blog::Constants::EMPTY_HASH

          def reason_field(name)
            scope = scope_for(name)
            errors = errors_for(name)

            Field(label: t(".reason")) do
              MarkdownEditor(**FieldError.control_attributes(:reason, errors, scope), **reason_props(name))
              FieldError(field: :reason, errors:, scope:)
            end
          end

          def reason_props(name)
            { name: "decision[reason]", value: value(name, :reason), height: HEIGHT, renderer: RENDERER,
              label: t(".reason"), placeholder: t(PLACEHOLDERS.fetch(name)) }
          end

          def reopen
            Form(action: path(:admin_reopen_decision, id: @decision.id), class: "stack-form") do
              reason_field(:reopen)
              Button(variant: :pri, type: "submit", small: true) { t(".reopen") }
            end
          end

          def resolve
            return Hint { t(".no_options") } if @decision.options.empty?

            Form(action: path(:admin_resolve_decision, id: @decision.id), class: "stack-form") do
              choice_field(errors_for(:resolve))
              reason_field(:resolve)
              Button(variant: :pri, type: "submit", small: true) { t(".resolve") }
            end
          end

          def scope_for(name) = "decision-#{name}"

          def value(name, field)
            return Blog::Constants::EMPTY_STRING unless @form[:name] == name

            Blog::Types::Text[@form[:params][field]]
          end
        end
      end
    end
  end
end

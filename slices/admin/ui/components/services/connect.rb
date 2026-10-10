# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Connect < Component
          PLAIN = %w[handle].freeze

          prop :definition, Blog::Types::Instance(::Services::Structs::Definition)
          prop :errors, Blog::Types::Hash
          prop :refusal, Blog::Types::String.optional

          def view_template
            Head(title: t(".heading", name: @definition.name))
            TokenForm(definition: @definition) do
              p(class: "field-error", role: "alert") { @refusal } if @refusal
              @definition.fields.each { field(it) }
              Hint { t(".hint", name: @definition.name) }
              Hint { t(".token_hint") } if @definition.oauth?
            end
          end

          private

          def field(name)
            Field(label: t(".fields").fetch(name.to_sym), name: name.to_sym, errors: @errors,
                  error: FieldError) do |control|
              Input(**control, type: input_type(name), autocomplete: "off", name: "connection[#{name}]")
            end
          end

          def input_type(name) = PLAIN.include?(name) ? "text" : "password"
        end
      end
    end
  end
end

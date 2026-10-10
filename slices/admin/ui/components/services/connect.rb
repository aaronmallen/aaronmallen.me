# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Connect < Component
          CLOSE_ICON = "fa-solid fa-xmark"
          LINK_ICON = "fa-solid fa-link"
          PLAIN = %w[handle].freeze

          prop :definition, Blog::Types::Instance(::Services::Structs::Definition)
          prop :errors, Blog::Types::Hash
          prop :refusal, Blog::Types::String.optional

          def view_template
            head
            Form(action: path(:admin_create_service, provider: @definition.id), class: "svc-connect") do
              p(class: "field-error", role: "alert") { @refusal } if @refusal
              @definition.fields.each { field(it) }
              Hint { t(".hint", name: @definition.name) }
              Hint { t(".token_hint") } if @definition.oauth?
              Button(variant: :pri, type: "submit", icon: LINK_ICON) { t(".connect", name: @definition.name) }
            end
          end

          private

          def close = { href: path(:admin_services), label: t(".close") }

          def field(name)
            Field(label: t(".fields").fetch(name.to_sym), name: name.to_sym, errors: @errors,
                  error: FieldError) do |control|
              Input(**control, type: input_type(name), autocomplete: "off", name: "connection[#{name}]")
            end
          end

          def head
            div(class: "svc-head") do
              h2(class: "card-title") { t(".heading", name: @definition.name) }
              Button(small: true, variant: :gh, icon: CLOSE_ICON, **close)
            end
          end

          def input_type(name) = PLAIN.include?(name) ? "text" : "password"
        end
      end
    end
  end
end

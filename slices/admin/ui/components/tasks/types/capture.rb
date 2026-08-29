# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        module Types
          class Capture < Component
            ERROR_FIELDS = %i[name color icon].freeze
            GALLERY = "https://fontawesome.com/search?ic=free&s=solid"
            SCOPE = "type"

            prop :values, Blog::Types::Hash
            prop :errors, Blog::Types::Hash

            def view_template
              div(class: "task-capture") do
                Form(action: path(:admin_create_task_type), class: "task-capture-row") do
                  name_field
                  icon_field
                  gallery
                  color_field
                  Button(variant: :pri, type: "submit") { t(".add") }
                end
                ERROR_FIELDS.each { Tasks::FieldError(field: it, errors: @errors, scope: SCOPE) }
              end
            end

            private

            def color_field
              fieldset(class: "swatch-set") do
                legend(class: "sr-only") { t(".color") }
                Swatches(name: "type[color]", scope: SCOPE, selected: @values[:color])
              end
            end

            def gallery
              text = t(".gallery")

              a(class: "btn gh", href: GALLERY, target: "_blank", rel: "noopener noreferrer", title: text,
                aria: { label: text }) do
                i(class: "fa-solid fa-arrow-up-right-from-square", aria: { hidden: "true" })
              end
            end

            def icon_field
              label(class: "sr-only", for: Tasks::FieldError.id_for(:icon, SCOPE)) { t(".icon") }
              Input(
                **Tasks::FieldError.control_attributes(:icon, @errors, SCOPE),
                autocomplete: "off",
                list: IconList::ID,
                name: "type[icon]",
                placeholder: t(".icon_placeholder"),
                value: @values[:icon],
              )
            end

            def name_field
              label(class: "sr-only", for: Tasks::FieldError.id_for(:name, SCOPE)) { t(".label") }
              Input(
                **Tasks::FieldError.control_attributes(:name, @errors, SCOPE),
                autocomplete: "off",
                name: "type[name]",
                placeholder: t(".placeholder"),
                value: @values[:name],
              )
            end
          end
        end
      end
    end
  end
end

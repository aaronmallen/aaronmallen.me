# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tags
        class Capture < Component
          SCOPE = "tag"

          prop :name, Blog::Types::String
          prop :errors, Blog::Types::Hash
          prop :tag_scope, Blog::Types::TagScope

          def view_template
            div(class: "tag-capture") do
              Form(action: path(:admin_create_tag), class: "tag-capture-row") do
                input(type: "hidden", name: "scope", value: @tag_scope)
                name_field
                Button(variant: :pri, type: "submit") { t(".add") }
              end
              FieldError(field: :name, errors: @errors, scope: SCOPE)
            end
          end

          private

          def name_field
            label(class: "sr-only", for: FieldError.id_for(:name, SCOPE)) { t(".label") }
            Input(
              **FieldError.control_attributes(:name, @errors, SCOPE),
              autocomplete: "off",
              name: "tag[name]",
              placeholder: t(".placeholder"),
              value: @name,
            )
          end
        end
      end
    end
  end
end

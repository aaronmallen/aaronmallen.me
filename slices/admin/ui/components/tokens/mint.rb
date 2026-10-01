# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tokens
        class Mint < Component
          prop :name, Blog::Types::String
          prop :errors, Blog::Types::Hash

          def view_template
            Form(action: path(:admin_create_token), class: "token-mint") do
              name_field
              Button(variant: :pri, type: "submit") { t(".mint") }
            end
            FieldError(field: :name, errors: @errors)
          end

          private

          def name_field
            label(class: "sr-only", for: FieldError.id_for(:name)) { t(".label") }
            Input(
              **FieldError.control_attributes(:name, @errors),
              autocomplete: "off",
              name: "token[name]",
              placeholder: t(".placeholder"),
              value: @name,
            )
          end
        end
      end
    end
  end
end

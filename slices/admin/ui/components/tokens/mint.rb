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
              Field(label: t(".label"), name: :name, errors: @errors, error: FieldError) do |control|
                Input(**control, autocomplete: "off", name: "token[name]", placeholder: t(".placeholder"), value: @name)
              end
              Button(variant: :pri, type: "submit", icon: "fa-solid fa-key") { t(".mint") }
            end
          end
        end
      end
    end
  end
end

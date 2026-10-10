# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tokens
        class Mint < Component
          prop :name, Blog::Types::String
          prop :scopes, Blog::Types::Array.of(Blog::Types::String)
          prop :expires_on, Blog::Types::String
          prop :errors, Blog::Types::Hash

          def view_template
            Form(action: path(:admin_create_token), class: "token-mint") do
              Field(label: t(".label"), name: :name, errors: @errors, error: FieldError) do |control|
                Input(**control, autocomplete: "off", name: "token[name]", placeholder: t(".placeholder"), value: @name)
              end
              scope_fields
              expiry_field
              Button(variant: :pri, type: "submit", icon: "fa-solid fa-key") { t(".mint") }
            end
          end

          private

          def expiry_field
            Field(label: t(".expires_on"), name: :expires_on, errors: @errors, error: FieldError) do |control|
              Input(**control, type: "date", name: "token[expires_on]", min: tomorrow, value: @expires_on)
              Hint { t(".expires_hint") }
            end
          end

          def scope_fields
            fieldset(class: "token-scopes") do
              legend(class: "f") { t(".scopes") }
              Blog::Types::OAuthScope.each_value do |scope|
                Checkbox(label: t(scope_key(scope)), name: "token[scopes][#{scope}]", checked: @scopes.include?(scope))
              end
              render FieldError.new(field: :scopes, errors: @errors)
            end
          end

          def scope_key(scope) = ".scope.#{scope}"

          def tomorrow = (Blog::TimeZone.today + 1).iso8601
        end
      end
    end
  end
end

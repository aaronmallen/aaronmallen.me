# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class TokenForm < Component
          LINK_ICON = "fa-solid fa-link"

          prop :definition, Blog::Types::Instance(::Services::Structs::Definition)

          def view_template(&)
            Form(action: path(:admin_create_service, provider: @definition.id), class: "svc-connect") do
              yield
              Button(variant: :pri, type: "submit", icon: LINK_ICON) { t(".connect", name: @definition.name) }
            end
          end
        end
      end
    end
  end
end

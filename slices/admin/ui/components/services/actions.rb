# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Actions < Component
          DISCONNECT_ICON = "fa-solid fa-link-slash"
          OPEN_ICON = "fa-solid fa-arrow-up-right-from-square"
          TEST_ICON = "fa-solid fa-plug-circle-check"

          prop :row, Blog::Types::Instance(Structs::ServiceRow)
          prop :connectable, Blog::Types::Bool

          def view_template
            div(class: "svc-actions") do
              test if @connectable && connection
              another if @connectable && definition.multiple
              dashboard
            end
            disconnect if connection
          end

          private

          def another
            Button(small: true, variant: :gh, href: path(:admin_services, connect: definition.id)) { t(".another") }
          end

          def connection = @row.connection

          def dashboard
            return unless definition.dashboard

            Button(small: true, variant: :gh, icon: OPEN_ICON, **external) { t(".open", name: definition.name) }
          end

          def definition = @row.definition

          def disconnect
            Form(**disconnect_attributes) do
              Button(small: true, variant: :warn, type: "submit", icon: DISCONNECT_ICON) { t(".disconnect") }
            end
          end

          def disconnect_attributes
            {
              action: path(:admin_disconnect_service, id: connection.id), class: "svc-disconnect",
              data: { confirm: t(".confirm_disconnect", name: definition.name, account: @row.account) },
            }
          end

          def external = { href: definition.dashboard, **OUTBOUND }

          def test
            Form(action: path(:admin_test_service, id: connection.id)) do
              Button(small: true, variant: :gh, type: "submit", icon: TEST_ICON) { t(".test") }
            end
          end
        end
      end
    end
  end
end

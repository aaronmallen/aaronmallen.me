# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Actions < Component
          ANOTHER_ICON = "fa-solid fa-plus"
          DISCONNECT_ICON = "fa-solid fa-link-slash"
          OPEN_ICON = "fa-solid fa-arrow-up-right-from-square"
          RECONNECT_ICON = "fa-solid fa-rotate"
          TEST_ICON = "fa-solid fa-plug-circle-check"

          prop :row, Blog::Types::Instance(Structs::ServiceRow)
          prop :connectable, Blog::Types::Bool

          def view_template
            div(class: "svc-actions") do
              reconnect if @row.status == :reconnect
              test if @connectable && connection
              another if @connectable && definition.multiple
              dashboard
            end
            disconnect if connection
          end

          private

          def another
            href = path(:admin_services, connect: definition.id)
            Button(small: true, variant: :gh, icon: ANOTHER_ICON, href:) { t(".another") }
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

          def reconnect
            Form(action: path(:admin_connect_service, provider: definition.id)) do
              input(type: "hidden", name: "connection", value: connection.id) if connection
              Button(small: true, variant: :pri, type: "submit", icon: RECONNECT_ICON) { t(".reconnect") }
            end
          end

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

# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Actions < Component
          ANOTHER_ICON = :add
          DISCONNECT_ICON = "fa-solid fa-link-slash"
          RECONNECT_ICON = "fa-solid fa-rotate"
          TEST_ICON = "fa-solid fa-plug-circle-check"

          prop :row, Blog::Types::Instance(Structs::ServiceRow)
          prop :connectable, Blog::Types::Bool

          def view_template
            div(class: "svc-actions") do
              reconnect if @row.reconnect?
              test if @connectable && connection
              another if @connectable && definition.multiple
              dashboard
            end
            disconnect if connection
          end

          private

          def another
            href = Helpers::ServiceTab.services(routes, connect: definition.id)
            Button(small: true, variant: :gh, icon: ANOTHER_ICON, href:) { t(".another") }
          end

          def connection = @row.connection

          def dashboard
            return unless definition.dashboard

            Button(small: true, variant: :gh, icon: :outbound, **external) { t(".open", name: definition.name) }
          end

          def definition = @row.definition

          def disconnect
            ButtonForm(
              action: path(:admin_disconnect_service, id: connection.id), class: "svc-disconnect",
              label: t(".disconnect"), variant: :warn, icon: DISCONNECT_ICON,
              confirm: t(".confirm_disconnect", name: definition.name, account: @row.account),
            )
          end

          def external = { href: definition.dashboard, **OUTBOUND }

          def held
            return Blog::Constants::EMPTY_HASH unless connection

            granted = definition.scopes.select { definition.granted?(it, connection.scopes) }
            { connection: connection.id, "scopes[]": granted.map { it[:id] } }
          end

          def reconnect
            ButtonForm(
              action: path(:admin_connect_service, provider: definition.id), label: t(".reconnect"), variant: :pri,
              icon: RECONNECT_ICON, hidden: held,
            )
          end

          def test
            ButtonForm(
              action: path(:admin_test_service, id: connection.id), label: t(".test"), variant: :gh, icon: TEST_ICON,
            )
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Services
        class Menu < View
          BUTTONS = Components::Services::Actions
          OPEN_ICON = "fa-regular fa-folder-open"

          layout nil

          prop :row, Blog::Types::Instance(Structs::ServiceRow)
          prop :connectable, Blog::Types::Bool

          def view_template
            ContextMenu(label: definition.name) do |menu|
              menu.link(t(".details"), href: path(:admin_services, selected: @row.key), icon: OPEN_ICON)
              reconnect(menu) if @row.reconnect?
              checks(menu) if @connectable
              dashboard(menu) if definition.dashboard
              disconnect(menu) if connection
            end
          end

          private

          def another(menu)
            menu.link(t(".another"), href: path(:admin_services, connect: definition.id), icon: BUTTONS::ANOTHER_ICON)
          end

          def checks(menu)
            test(menu) if connection
            another(menu) if definition.multiple
          end

          def connection = @row.connection

          def dashboard(menu)
            label = t(".open", name: definition.name)

            menu.link(label, href: definition.dashboard, icon: BUTTONS::OPEN_ICON, outbound: true)
          end

          def definition = @row.definition

          def disconnect(menu)
            action = path(:admin_disconnect_service, id: connection.id)
            icon = BUTTONS::DISCONNECT_ICON

            menu.separator
            menu.post(t(".disconnect"), action:, icon:, warn: true, confirm: t(".confirm_disconnect"))
          end

          def reconnect(menu)
            action = path(:admin_connect_service, provider: definition.id)
            fields = connection ? { connection: connection.id } : Blog::Constants::EMPTY_HASH

            menu.post(t(".reconnect"), action:, icon: BUTTONS::RECONNECT_ICON, fields:, morph: false)
          end

          def test(menu)
            menu.post(t(".test"), action: path(:admin_test_service, id: connection.id), icon: BUTTONS::TEST_ICON)
          end
        end
      end
    end
  end
end

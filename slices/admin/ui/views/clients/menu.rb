# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Clients
        class Menu < View
          layout nil

          prop :client, Blog::Types::Instance(ROM::Struct)

          def view_template
            ContextMenu(label: @client.display_name) do |menu|
              menu.link(t(".sightings"), href: path(:admin_security), icon: "fa-solid fa-shield-halved")
              menu.separator
              menu.post(t(".revoke"), action: path(:admin_revoke_client, id: @client.id), icon: :ban,
                                      warn: true, confirm: t(".confirm_revoke"))
            end
          end
        end
      end
    end
  end
end

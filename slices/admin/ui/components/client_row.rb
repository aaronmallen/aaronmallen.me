# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ClientRow < Component
        prop :client, Blog::Types::Instance(ROM::Struct)

        def view_template
          ListItem(title: name, data: { menu: path(:admin_client_menu, id: @client.id) }) do |item|
            item.sub { sub }
            revoke_form
          end
        end

        private

        def connected
          Stamped(text: dotted(redirect_host, t(".connected", time: Stamped::MARK)), at: @client.created_at)
        end

        def last_used
          return plain(t(".never_used")) if @client.last_used_at.nil?

          Stamped(text: t(".last_used", time: Stamped::MARK), at: @client.last_used_at)
        end

        def name = @client.display_name

        def redirect_host = @client.redirect_host.then { it unless it == name }

        def revoke_form
          ButtonForm(
            action: path(:admin_revoke_client, id: @client.id), label: t(".revoke"), variant: :warn,
            confirm: t(".confirm_revoke", client: name),
          )
        end

        def sub
          Dotted do |line|
            line.part { connected }
            line.part { last_used }
            line.part { a(class: "settings-link", href: path(:admin_security)) { t(".sightings") } }
          end
        end
      end
    end
  end
end

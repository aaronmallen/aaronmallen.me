# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ClientRow < Component
        prop :client, Blog::Types::Instance(ROM::Struct)

        def view_template
          ListItem(title: name) do |item|
            item.meta { p(class: "li-sub") { sub } }
            revoke_form
          end
        end

        private

        def connected
          Stamped(text: dotted(redirect_host, t(".connected", time: Stamped::MARK)), at: @client.created_at)
        end

        def host
          Blog::Types::Normalized::Host.call(@client.redirect_uris.first) { Blog::Constants::EMPTY_STRING }
        end

        def last_used
          return plain(t(".never_used")) if @client.last_used_at.nil?

          Stamped(text: t(".last_used", time: Stamped::MARK), at: @client.last_used_at)
        end

        def name
          return registered_name unless registered_name.empty?

          host.empty? ? @client.client_id : host
        end

        def redirect_host
          host unless host.empty? || host == name
        end

        def registered_name = @client.client_name.to_s.strip

        def revoke_attributes
          {
            action: path(:admin_revoke_client, id: @client.id),
            data: { confirm: t(".confirm_revoke", client: name) },
          }
        end

        def revoke_form
          Form(**revoke_attributes) do
            Button(variant: :warn, small: true, type: "submit") { t(".revoke") }
          end
        end

        def sub
          connected
          plain(DOT)
          last_used
          plain(DOT)
          a(class: "settings-link", href: path(:admin_security)) { t(".sightings") }
        end
      end
    end
  end
end

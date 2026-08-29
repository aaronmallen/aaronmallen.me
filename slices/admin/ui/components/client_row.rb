# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ClientRow < Component
        SEPARATOR = " · "

        prop :client, Blog::Types::Instance(ROM::Struct)

        def view_template
          ListItem(title: name, sub:) { revoke_form }
        end

        private

        def connected = t(".connected", time: l(Blog::TimeZone.local(@client.created_at), format: :medium))

        def host
          Blog::Types::Normalized::Host.call(@client.redirect_uris.first) { Dry::Core::Constants::EMPTY_STRING }
        end

        def last_used
          return t(".never_used") if @client.last_used_at.nil?

          t(".last_used", time: l(Blog::TimeZone.local(@client.last_used_at), format: :medium))
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

        def sub = [redirect_host, connected, last_used].compact.join(SEPARATOR)
      end
    end
  end
end

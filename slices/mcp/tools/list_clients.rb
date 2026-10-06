# frozen_string_literal: true

module MCP
  module Tools
    class ListClients < Base
      SCHEMA = { additionalProperties: false }.freeze

      description "List the connected MCP clients, newest first, each with its ID, name, the scopes its live " \
                  "tokens hold, when it connected and when it was last used, null if never. Last use updates at " \
                  "most every #{Operations::Authenticate::TOUCH_EVERY / 60} minutes. current is true for the " \
                  "client making this call. A client names itself when it registers, so the name comes marked " \
                  "untrusted. Revoking a client stays in the admin. #{Untrusted::WARNING}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:)
          clients = dep(:connected_clients, server_context).call
          scopes = dep(:granted_scopes, server_context).call(clients.map(&:id))
          caller_id = dep(:oauth_client_id, server_context)

          answer(clients: clients.map { entry(it, scopes.fetch(it.id), caller_id) })
        end

        private

        def display_name(client)
          [client.client_name, Blog::Types::Normalized::Host.call(client.redirect_uris.first) { nil }]
            .map { it.to_s.strip }.find { !it.empty? } || client.client_id
        end

        def entry(client, scopes, caller_id)
          {
            id: client.id,
            name: Untrusted.call(display_name(client)),
            scopes:,
            created_at: client.created_at.utc.iso8601,
            last_used_at: client.last_used_at&.utc&.iso8601,
            current: client.id == caller_id,
          }
        end
      end
    end
  end
end

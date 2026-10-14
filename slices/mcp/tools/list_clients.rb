# frozen_string_literal: true

module MCP
  module Tools
    class ListClients < Base
      description "List the connected MCP clients, newest first, each with its ID, name, the scopes its live " \
                  "tokens hold, when it connected and when it was last used, null if never. Last use updates at " \
                  "most every #{Operations::Authenticate::TOUCH_EVERY / 60} minutes. current is true for the " \
                  "client making this call. A client names itself when it registers, so the name comes marked " \
                  "untrusted. Revoking a client stays in the admin. #{Untrusted::WARNING}"
      endpoint scope: Blog::Types::OAuthScope["read"]

      class << self
        private

        def entry(client, caller_id)
          client.merge("name" => Untrusted.call(client.fetch("name")), "current" => client.fetch("id") == caller_id)
        end

        def reply(payload, server_context)
          caller_id = server_context.fetch(:oauth_client_id)

          answer(clients: payload.fetch(:clients).map { entry(it, caller_id) })
        end
      end
    end
  end
end

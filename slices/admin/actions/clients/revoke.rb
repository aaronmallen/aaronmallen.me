# frozen_string_literal: true

module Admin
  module Actions
    module Clients
      class Revoke < Action
        REVOKED = "clients_page.toasts.revoked"

        include Deps[revoke_client: "mcp.operations.revoke_client"]

        def handle(request, response)
          halt 404 if revoke_client.call(record_id(request)).failure?

          toast(response, REVOKED)
          response.redirect_to(routes.path(:admin_clients))
        end
      end
    end
  end
end

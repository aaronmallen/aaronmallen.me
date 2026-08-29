# frozen_string_literal: true

module Admin
  module Actions
    module Clients
      class Index < Action
        include Deps[connected_clients: "mcp.queries.connected_clients"]

        def handle(_request, response)
          response[:clients] = connected_clients.call
        end
      end
    end
  end
end

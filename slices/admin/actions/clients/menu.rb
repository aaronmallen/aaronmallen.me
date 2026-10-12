# frozen_string_literal: true

module Admin
  module Actions
    module Clients
      class Menu < Action
        include Deps[oauth_client_queries: "mcp.repos.oauth_client_queries"]

        def handle(request, response)
          id = record_id(request)

          response.render(view, client: oauth_client_queries.connected.find { it.id == id } || halt(404))
        end
      end
    end
  end
end

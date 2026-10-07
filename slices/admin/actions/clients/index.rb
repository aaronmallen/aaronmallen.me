# frozen_string_literal: true

module Admin
  module Actions
    module Clients
      class Index < Action
        include Deps[oauth_client_queries: "mcp.repos.oauth_client_queries"]

        def handle(_request, response)
          response[:clients] = oauth_client_queries.connected
        end
      end
    end
  end
end

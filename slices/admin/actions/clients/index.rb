# frozen_string_literal: true

module Admin
  module Actions
    module Clients
      class Index < Action
        include Deps[client_queries: "api.repos.client_queries"]

        def handle(_request, response)
          response[:clients] = client_queries.connected
        end
      end
    end
  end
end

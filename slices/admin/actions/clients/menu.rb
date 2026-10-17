# frozen_string_literal: true

module Admin
  module Actions
    module Clients
      class Menu < Action
        include Deps[client_queries: "api.repos.client_queries"]

        def handle(request, response)
          id = record_id(request)

          response.render(view, client: client_queries.connected.find { it.id == id } || halt(:not_found))
        end
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module Actions
    module Tokens
      class Menu < Action
        include Deps[api_token_queries: "api.repos.api_token_queries"]

        def handle(request, response)
          id = record_id(request)

          response.render(view, token: api_token_queries.live.find { it.id == id } || halt(404))
        end
      end
    end
  end
end

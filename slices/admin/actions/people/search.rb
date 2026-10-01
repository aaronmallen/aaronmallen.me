# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Search < Action
        STATUSES = { failed: 502, rate_limited: 429 }.freeze

        include Deps[search_accounts: "operations.search_accounts"]

        def handle(request, response)
          network = request.params[:network]

          case search_accounts.call(network:, query: request.params[:q])
          in Success(*accounts) then response.render(view, network:, accounts:)
          in Failure(:unconfigured) then halt 404
          in Failure(problem)
            response.status = STATUSES.fetch(problem)
            response.render(view, network:, problem:)
          end
        end
      end
    end
  end
end

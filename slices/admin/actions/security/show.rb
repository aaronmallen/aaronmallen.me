# frozen_string_literal: true

module Admin
  module Actions
    module Security
      class Show < Action
        include Deps[
          "settings",
          api_token_queries: "api.repos.api_token_queries",
          oauth_client_queries: "mcp.repos.oauth_client_queries",
          sighting_queries: "security.repos.sighting_queries",
          sign_in_queries: "security.repos.sign_in_queries",
        ]

        def handle(_request, response)
          response.render(
            view,
            clients: oauth_client_queries.connected,
            honeybadger_url: settings.honeybadger[:project_url],
            sightings: sighting_queries.newest_first,
            sign_ins: sign_in_queries.newest_first,
            tokens: api_token_queries.live,
          )
        end
      end
    end
  end
end

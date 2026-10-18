# frozen_string_literal: true

module Admin
  module Actions
    module Security
      class Show < Action
        include Deps[
          "settings",
          api_token_queries: "api.repos.api_token_queries",
          client_queries: "api.repos.client_queries",
          sighting_queries: "security.repos.sighting_queries",
          sign_in_queries: "security.repos.sign_in_queries",
        ]

        def handle(request, response)
          sign_ins = sign_in_queries.page(requested_page(request, response))
          not_found(response) if sign_ins.past_end?

          response.render(
            view,
            clients: client_queries.connected,
            honeybadger_url: settings.honeybadger[:project_url],
            sightings: sighting_queries.newest_first,
            sign_ins:,
            tokens: api_token_queries.live,
          )
        end
      end
    end
  end
end

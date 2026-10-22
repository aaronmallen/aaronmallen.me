# frozen_string_literal: true

module Admin
  module Actions
    module Security
      class Show < Action
        include Deps[
          "settings",
          api_token_queries: "api.repos.api_token_queries",
          build_settings_tabs: "operations.build_settings_tabs",
          client_queries: "api.repos.client_queries",
          device_queries: "security.repos.device_queries",
          sighting_queries: "security.repos.sighting_queries",
          sign_in_queries: "security.repos.sign_in_queries",
        ]

        def handle(request, response)
          sign_ins = sign_in_queries.page(requested_page(request, response))
          not_found(response) if sign_ins.past_end?

          response.render(
            view,
            **credentials,
            devices: device_queries.newest_first,
            honeybadger_url: settings.honeybadger[:project_url],
            sign_ins:,
            tabs: build_settings_tabs.call,
          )
        end

        private

        def credentials
          {
            clients: client_queries.connected, sightings: sighting_queries.newest_first, tokens: api_token_queries.live,
          }
        end
      end
    end
  end
end

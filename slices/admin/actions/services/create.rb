# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Create < Action
        CONNECTED = "services_page.toasts.connected"
        REFUSALS = {
          refused: "services_page.refusals.refused", single: "services_page.refusals.single",
          taken: "services_page.refusals.taken",
        }.freeze

        include Deps[
          "operations.build_services_page",
          connect_service: "operations.connect_service",
          definition_queries: "services.repos.definition_queries",
          services_view: "ui.views.settings.services",
        ]

        before :allow_oauth_redirects

        def handle(request, response)
          provider = request.params[:provider]

          case connect_service.call(provider, Blog::Types::Fields[request.params[:connection]])
            in Success(connection) then connected(response, connection)
            in Failure(:not_found) then halt :not_found
            in Failure[:invalid, errors] then rejected(response, provider, errors:)
            in Failure[:refused, reason] then rejected(response, provider, refusal: refusal(:refused, reason:))
            in Failure(:single | :taken => code) then rejected(response, provider, refusal: refusal(code))
          end
        end

        private

        def connected(response, connection)
          name = definition_queries.find(connection.provider).name
          toast(response, CONNECTED, name:, account: connection.label)
          response.redirect_to(Helpers::ServiceTab.services(routes, selected: connection.id))
        end

        def refusal(code, **) = i18n.t!(REFUSALS.fetch(code), **)

        def rejected(response, connect, **)
          unprocessable(response, services_view, **build_services_page.call(services: { connect:, ** }))
        end
      end
    end
  end
end

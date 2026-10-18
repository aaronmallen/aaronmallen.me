# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Test < Action
        ANSWERED = "services_page.toasts.answered"
        UNANSWERED = "services_page.toasts.unanswered"

        include Deps[
          check_service: "operations.check_service",
          connection_queries: "services.repos.connection_queries",
          definition_queries: "services.repos.definition_queries",
        ]

        def handle(request, response)
          connection = connection_queries.by_id(record_id(request)) || halt(:not_found)

          report(response, connection)
          response.redirect_to(Helpers::ServiceTab.services(routes, selected: connection.id))
        end

        private

        def report(response, connection)
          name = definition_queries.find(connection.provider)&.name || halt(:not_found)

          case check_service.call(connection.provider, connection.credentials)
            in Success(_) then toast(response, ANSWERED, name:)
            in Failure[:refused, reason] then toast(response, UNANSWERED, name:, reason:)
            in Failure(:not_found) then halt :not_found
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Work < Action
        GOOGLE = Blog::Types::ServiceProvider["google"]
        PERSONAL = "services_page.toasts.personal"
        WORK = "services_page.toasts.work"

        include Deps[
          change_connection: "services.operations.change_connection",
          connection_queries: "services.repos.connection_queries",
        ]

        def handle(request, response)
          connection = connection_queries.by_id(record_id(request))
          halt :not_found unless connection&.provider == GOOGLE

          work = request.params[:work] == Blog::Constants::CHECKED
          change_connection.call(connection.id, work:)
          toast(response, work ? WORK : PERSONAL, account: connection.label)
          response.redirect_to(Helpers::ServiceTab.services(routes, selected: connection.id))
        end
      end
    end
  end
end

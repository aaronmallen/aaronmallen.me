# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Destroy < Action
        DISCONNECTED = "services_page.toasts.disconnected"

        include Deps[remove_connection: "services.operations.remove_connection"]

        def handle(request, response)
          settle(response, remove_connection.call(record_id(request)), DISCONNECTED, routes.path(:admin_services))
        end
      end
    end
  end
end

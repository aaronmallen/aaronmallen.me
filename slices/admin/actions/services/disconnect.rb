# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Disconnect < Action
        DISCONNECTED = "services_page.toasts.disconnected"

        include Deps[disconnect_service: "operations.disconnect_service"]

        def handle(request, response)
          result = disconnect_service.call(record_id(request))
          halt 404 if result.failure?

          toast(response, DISCONNECTED, name: result.value!.label)
          response.redirect_to(routes.path(:admin_services))
        end
      end
    end
  end
end

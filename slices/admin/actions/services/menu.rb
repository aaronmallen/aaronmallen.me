# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Menu < Action
        include Deps[check_service: "operations.check_service", list_services: "operations.list_services"]

        def handle(request, response)
          row = list_services.call[:rows].find { it.key == request.params[:key] } || halt(:not_found)

          response.render(view, row:, connectable: check_service.checks?(row.definition.id))
        end
      end
    end
  end
end

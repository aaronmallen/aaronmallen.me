# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Index < Action
        include Deps[list_services: "operations.list_services"]

        def handle(request, response)
          listing = list_services.call
          selected = request.params[:selected].to_s

          response.render(view, **listing, selected: listing[:rows].find { it.key == selected })
        end
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Index < Action
        include Deps[
          check_service: "operations.check_service",
          definition_queries: "services.repos.definition_queries",
          list_services: "operations.list_services",
        ]

        def handle(request, response)
          response.render(view, **listing(request.params[:connect], selected: request.params[:selected]))
        end

        private

        def listing(connect, selected: nil, **)
          listing = list_services.call
          connectable = definition_queries.all.select { check_service.checks?(it.id) }

          listing.merge(
            connect: connectable.find { it.id == connect.to_s }, connectable: connectable.map(&:id),
            selected: listing[:rows].find { it.key == selected.to_s }, **,
          )
        end
      end
    end
  end
end

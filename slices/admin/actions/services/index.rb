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

        before :allow_oauth_redirects

        def handle(request, response)
          response.render(view, **listing(request.params[:connect], selected: request.params[:selected]))
        end

        private

        def allow_oauth_redirects(_request, response)
          policy = Slice.config.actions.content_security_policy.dup
          policy[:form_action] = "'self' https:"
          response.headers["Content-Security-Policy"] = policy.to_s
        end

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

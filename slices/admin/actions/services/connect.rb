# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Connect < Action
        NOT_CONFIGURED = "services_page.toasts.not_configured"

        include Deps[definition_queries: "services.repos.definition_queries", github: "github.auth"]

        def handle(request, response)
          provider = request.params[:provider]
          definition = definition_queries.find(provider) || halt(404)
          return not_configured(response) unless github.configured?

          response.redirect_to(connect_url(request, definition))
        end

        private

        def connect_url(request, definition)
          started = Auth::ConnectState.new(request.session).start(definition.id)
          scope = definition.scopes.map { it[:id] }.join(" ")

          github.connect_url(redirect_uri: github_service_callback_url, scope:, **started)
        end

        def not_configured(response)
          toast(response, NOT_CONFIGURED)
          response.redirect_to(routes.path(:admin_services))
        end
      end
    end
  end
end

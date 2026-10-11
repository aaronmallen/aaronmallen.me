# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Connect < Action
        GOOGLE_HEALTH = Blog::Types::ServiceProvider["google_health"]
        TOASTS = "services_page.toasts"

        include Deps[
          definition_queries: "services.repos.definition_queries",
          github: "github.auth",
          google_health: "health.google.client",
          mastodon: "mastodon.auth",
          register_mastodon_app: "operations.register_mastodon_app",
        ]

        def handle(request, response)
          definition = definition_queries.find(request.params[:provider]) || halt(404)

          case connect_url(request, definition)
            in Success(url) then response.redirect_to(url)
            in Failure(reason) then refuse(response, reason, definition.name)
          end
        end

        private

        def connect_url(request, definition)
          scope = definition.scopes.map { it[:id] }.join(" ")
          return mastodon_url(request, definition, scope) if definition.host

          client, redirect_uri = oauth_client(definition)
          return Failure(:not_configured) unless client.configured?

          started = Auth::ConnectState.new(request.session).start(definition.id)
          Success(client.connect_url(redirect_uri:, scope:, **started))
        end

        def mastodon_url(request, definition, scope)
          redirect_uri = mastodon_service_callback_url

          register_mastodon_app.call(request.params[:server], redirect_uri:, scope:).fmap do |registered|
            host, app = registered.values_at(:host, :app)
            started = Auth::ConnectState.new(request.session).start(definition.id, host:)
            mastodon.connect_url(host, app, redirect_uri:, scope:, **started)
          end
        end

        def oauth_client(definition)
          return [google_health, google_health_service_callback_url] if definition.id == GOOGLE_HEALTH

          [github, github_callback_url]
        end

        def refuse(response, reason, name)
          toast(response, "#{TOASTS}.#{reason}", name:)
          response.redirect_to(routes.path(:admin_services))
        end
      end
    end
  end
end

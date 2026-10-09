# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Connect < Action
        MASTODON = "mastodon"
        TOASTS = "services_page.toasts"

        include Deps[
          definition_queries: "services.repos.definition_queries",
          github: "github.auth",
          mastodon: "mastodon.auth",
          register_mastodon_app: "operations.register_mastodon_app",
        ]

        def handle(request, response)
          definition = definition_queries.find(request.params[:provider]) || halt(404)

          case connect_url(request, definition)
            in Success(url) then response.redirect_to(url)
            in Failure(reason) then refuse(response, reason)
          end
        end

        private

        def connect_url(request, definition)
          scope = definition.scopes.map { it[:id] }.join(" ")
          definition.id == MASTODON ? mastodon_url(request, scope) : github_url(request, definition, scope)
        end

        def github_url(request, definition, scope)
          return Failure(:not_configured) unless github.configured?

          started = Auth::ConnectState.new(request.session).start(definition.id)
          Success(github.connect_url(redirect_uri: github_callback_url, scope:, **started))
        end

        def mastodon_url(request, scope)
          redirect_uri = mastodon_service_callback_url

          register_mastodon_app.call(request.params[:server], redirect_uri:, scope:).fmap do |registered|
            host, app = registered.values_at(:host, :app)
            started = Auth::ConnectState.new(request.session).start(MASTODON, host:)
            mastodon.connect_url(host, app, redirect_uri:, scope:, **started)
          end
        end

        def refuse(response, reason)
          toast(response, "#{TOASTS}.#{reason}")
          response.redirect_to(routes.path(:admin_services))
        end
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module Actions
    module Services
      class Connect < Action
        GOOGLE = Blog::Types::ServiceProvider["google"]
        LINKEDIN = Blog::Types::ServiceProvider["linkedin"]
        TOASTS = "services_page.toasts"

        include Deps[
          definition_queries: "services.repos.definition_queries",
          github: "github.auth",
          google: "google.client",
          linkedin: "linkedin.auth",
          mastodon: "mastodon.auth",
          register_mastodon_app: "operations.register_mastodon_app",
        ]

        def handle(request, response)
          definition = definition_queries.find(request.params[:provider]) || halt(:not_found)

          case connect_url(request, definition)
            in Success(url) then response.redirect_to(url)
            in Failure(reason) then refuse(response, reason, definition.name)
          end
        end

        private

        def connect_url(request, definition)
          scope = definition.wanted(Array(request.params[:scopes])).map { it[:id] }.join(" ")
          return mastodon_url(request, definition, scope) if definition.host

          oauth_url(request, definition, scope)
        end

        def mastodon_url(request, definition, scope)
          redirect_uri = auth_callback_url(definition.id)

          register_mastodon_app.call(request.params[:server], redirect_uri:, scope:).fmap do |registered|
            host, app = registered.values_at(:host, :app)
            started = Auth::ConnectState.new(request.session).start(definition.id, host:)
            mastodon.connect_url(host, app, redirect_uri:, scope:, **started)
          end
        end

        def oauth_url(request, definition, scope)
          client = { GOOGLE => google, LINKEDIN => linkedin }.fetch(definition.id, github)
          return Failure(:not_configured) unless client.configured?

          Success(client.connect_url(redirect_uri: auth_callback_url(definition.id), scope:,
                                     **started(request, definition)))
        end

        def refuse(response, reason, name)
          toast(response, "#{TOASTS}.#{reason}", name:)
          response.redirect_to(Helpers::ServiceTab.services(routes))
        end

        def started(request, definition)
          connection = Blog::Types::IdParam[request.params[:connection]]
          Auth::ConnectState.new(request.session).start(definition.id, connection:)
        end
      end
    end
  end
end

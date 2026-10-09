# frozen_string_literal: true

require "multi_xml"

module Admin
  module Operations
    class RegisterMastodonApp < Operation
      PROVIDER = "mastodon"
      SERVER = /\A[\w-]+(\.[\w-]+)+\z/

      include Deps[
        app_queries: "services.repos.app_queries",
        mastodon: "mastodon.auth",
        save_app: "services.operations.save_app",
      ]

      def call(server, redirect_uri:, scope:)
        host = step host(server)
        held = app_queries.find(PROVIDER, host)
        return { host:, app: held.credentials } if held && fits?(held, redirect_uri, scope)

        app = step register(host, redirect_uri:, scope:)
        step save_app.call(provider: PROVIDER, host:, redirect_uri:, scopes: scope.split, credentials: app)
        { host:, app: }
      end

      private

      def fits?(held, redirect_uri, scope) = held.redirect_uri == redirect_uri && held.scopes.sort == scope.split.sort

      def host(server)
        given = server.to_s.strip
        host = Blog::Types::Normalized::Host.call(given.include?("://") ? given : "https://#{given}") { nil }

        host&.match?(SERVER) ? Success(host) : Failure(:bad_server)
      end

      def register(host, **)
        Success(mastodon.register(host, **))
      rescue OAuth2::Error, Faraday::Error, KeyError, JSON::ParserError, MultiXML::ParseError
        Failure(:mastodon_failed)
      end
    end
  end
end

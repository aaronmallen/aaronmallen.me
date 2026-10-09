# frozen_string_literal: true

require "multi_xml"

module Admin
  module Operations
    class ConnectMastodon < Operation
      PROVIDER = "mastodon"

      include Deps[
        add_connection: "services.operations.add_connection",
        app_queries: "services.repos.app_queries",
        mastodon: "mastodon.auth",
      ]

      def call(host:, code:, redirect_uri:, code_verifier:)
        app = step(found(app_queries.find(PROVIDER, host)).alt_map { :mastodon_failed })
        grant = step fetch_grant(host, app.credentials, code:, redirect_uri:, code_verifier:)
        access_token = grant.delete(:access_token)

        step add_connection.call(provider: PROVIDER, host:, credentials: { access_token:, **app.credentials }, **grant)
      end

      private

      def fetch_grant(...)
        Success(mastodon.grant(...))
      rescue OAuth2::Error, Faraday::Error, KeyError, JSON::ParserError, MultiXML::ParseError
        Failure(:mastodon_failed)
      end
    end
  end
end

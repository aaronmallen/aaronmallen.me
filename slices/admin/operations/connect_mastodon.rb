# frozen_string_literal: true

require "multi_xml"

module Admin
  module Operations
    class ConnectMastodon < Blog::Operation
      PROVIDER = Blog::Types::ServiceProvider["mastodon"]

      include Deps[
        add_connection: "services.operations.add_connection",
        app_queries: "services.repos.app_queries",
        change_connection: "services.operations.change_connection",
        connection_queries: "services.repos.connection_queries",
        mastodon: "mastodon.auth",
      ]

      def call(host:, code:, redirect_uri:, code_verifier:)
        app = step(found(app_queries.find(PROVIDER, host)).alt_map { :mastodon_failed })
        grant = step fetch_grant(host, app.credentials, code:, redirect_uri:, code_verifier:)
        access_token = grant.delete(:access_token)

        step save(held(host, grant[:account_id]), host:, credentials: { access_token:, **app.credentials }, **grant)
      end

      private

      def fetch_grant(...)
        Success(mastodon.grant(...))
      rescue OAuth2::Error, Faraday::Error, KeyError, JSON::ParserError, MultiXML::ParseError
        Failure(:mastodon_failed)
      end

      def held(host, account_id)
        connection_queries.for(PROVIDER).find { it.host == host && it.account_id == account_id }
      end

      def save(held, **grant)
        return add_connection.call(provider: PROVIDER, **grant) if held.nil?

        change_connection.call(held.id, **grant.except(:account_id, :host), revoked_at: nil)
        Success(connection_queries.by_id(held.id))
      end
    end
  end
end

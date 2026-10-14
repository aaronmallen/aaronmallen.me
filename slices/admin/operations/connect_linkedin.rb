# frozen_string_literal: true

require "multi_xml"

module Admin
  module Operations
    class ConnectLinkedIn < Blog::Operation
      PROVIDER = Blog::Types::ServiceProvider["linkedin"]

      include Deps[
        add_connection: "services.operations.add_connection",
        change_connection: "services.operations.change_connection",
        connection_queries: "services.repos.connection_queries",
        linkedin: "linkedin.auth",
      ]

      def call(code:, redirect_uri:)
        grant = step fetch_grant(code:, redirect_uri:)
        lapses_at = grant[:credentials][:expires_at]&.then { Time.at(it) }

        step save(connection_queries.for(PROVIDER).find { it.account_id == grant[:account_id] }, **grant, lapses_at:)
      end

      private

      def fetch_grant(**)
        Success(linkedin.grant(**))
      rescue OAuth2::Error, Faraday::Error, KeyError, JSON::ParserError, MultiXML::ParseError
        Failure(:linkedin_failed)
      end

      def save(held, **grant)
        return add_connection.call(provider: PROVIDER, **grant) if held.nil?

        change_connection.call(held.id, **grant.except(:account_id), revoked_at: nil)
        Success(connection_queries.by_id(held.id))
      end
    end
  end
end

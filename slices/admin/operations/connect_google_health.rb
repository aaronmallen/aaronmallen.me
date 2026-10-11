# frozen_string_literal: true

module Admin
  module Operations
    class ConnectGoogleHealth < Blog::Operation
      PROVIDER = Blog::Types::ServiceProvider["google_health"]

      include Deps[
        add_connection: "services.operations.add_connection",
        change_connection: "services.operations.change_connection",
        connection_queries: "services.repos.connection_queries",
        google_health: "health.google.client",
      ]

      def call(code:, redirect_uri:, code_verifier:)
        grant = step fetch_grant(code:, redirect_uri:, code_verifier:)
        held = connection_queries.for(PROVIDER).first
        return step add_connection.call(provider: PROVIDER, **grant) if held.nil?

        change_connection.call(held.id, **grant, revoked_at: nil)
        connection_queries.by_id(held.id)
      end

      private

      def fetch_grant(**)
        Success(google_health.grant(**))
      rescue OAuth2::Error, Faraday::Error
        Failure(:google_health_failed)
      end
    end
  end
end

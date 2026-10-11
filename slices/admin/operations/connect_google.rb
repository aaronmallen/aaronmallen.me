# frozen_string_literal: true

module Admin
  module Operations
    class ConnectGoogle < Blog::Operation
      HEALTH = "https://www.googleapis.com/auth/googlehealth."
      PROVIDER = Blog::Types::ServiceProvider["google"]

      include Deps[
        add_connection: "services.operations.add_connection",
        change_connection: "services.operations.change_connection",
        connection_queries: "services.repos.connection_queries",
        google: "google.google.client",
        queue_backfill: "health.operations.queue_backfill",
      ]

      def call(code:, redirect_uri:, code_verifier:, connection: nil)
        grant = step fetch_grant(code:, redirect_uri:, code_verifier:)
        held = held(grant[:account_id], connection)
        saved = step save(held, grant)
        queue_backfill.call if health?(grant[:scopes]) && !health?(held&.scopes || [])
        saved
      end

      private

      def fetch_grant(**)
        Success(google.grant(**))
      rescue OAuth2::Error, Faraday::Error, KeyError
        Failure(:google_failed)
      end

      def health?(scopes) = scopes.any? { it.start_with?(HEALTH) }

      def held(account_id, id)
        accounts = connection_queries.for(PROVIDER)
        accounts.find { it.account_id == account_id } || accounts.find { it.id == id }
      end

      def save(held, grant)
        return add_connection.call(provider: PROVIDER, **grant) if held.nil?

        change_connection.call(held.id, **grant, revoked_at: nil)
        Success(connection_queries.by_id(held.id))
      end
    end
  end
end

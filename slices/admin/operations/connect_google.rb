# frozen_string_literal: true

module Admin
  module Operations
    class ConnectGoogle < ConnectOperation
      HEALTH = "https://www.googleapis.com/auth/googlehealth."
      PROVIDER = Blog::Types::ServiceProvider["google"]

      include Deps[
        google: "google.client",
        queue_backfill: "health.operations.queue_backfill",
      ]

      def call(code:, redirect_uri:, code_verifier:, connection: nil)
        grant = step fetch_grant(code:, redirect_uri:, code_verifier:)
        held = held(grant[:account_id], connection)
        saved = step save(held, **grant)
        queue_backfill.call if health?(grant[:scopes]) && !health?(held&.scopes || [])
        saved
      end

      private

      def fetch_grant(**)
        Success(google.grant(**))
      rescue Blog::ServiceError
        Failure(:google_failed)
      end

      def health?(scopes) = scopes.any? { it.start_with?(HEALTH) }

      def held(account_id, id)
        accounts = connection_queries.for(PROVIDER)
        accounts.find { it.account_id == account_id } || accounts.find { it.id == id && !it.account_id.include?("@") }
      end
    end
  end
end

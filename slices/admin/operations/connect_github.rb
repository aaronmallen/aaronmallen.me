# frozen_string_literal: true

module Admin
  module Operations
    class ConnectGitHub < Blog::Operation
      PROVIDER = Blog::Types::ServiceProvider["github"]

      include Deps[
        add_connection: "services.operations.add_connection",
        change_connection: "services.operations.change_connection",
        connection_queries: "services.repos.connection_queries",
        github: "github.auth",
      ]

      def call(code:, redirect_uri:, code_verifier:)
        grant = step fetch_grant(code:, redirect_uri:, code_verifier:)
        access_token = grant.delete(:access_token)
        held = connection_queries.for(PROVIDER).find { it.account_id == grant[:account_id] }

        step save(held, credentials: { access_token: }, **grant)
      end

      private

      def fetch_grant(**)
        Success(github.grant(**))
      rescue OAuth2::Error, Faraday::Error, KeyError
        Failure(:github_failed)
      end

      def save(held, **grant)
        return add_connection.call(provider: PROVIDER, **grant) if held.nil?

        change_connection.call(held.id, **grant.except(:account_id), revoked_at: nil)
        Success(connection_queries.by_id(held.id))
      end
    end
  end
end

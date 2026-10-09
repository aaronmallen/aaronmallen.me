# frozen_string_literal: true

module Admin
  module Operations
    class ConnectGitHub < Operation
      PROVIDER = "github"

      include Deps[add_connection: "services.operations.add_connection", github: "github.auth"]

      def call(code:, redirect_uri:, code_verifier:)
        grant = step fetch_grant(code:, redirect_uri:, code_verifier:)
        access_token = grant.delete(:access_token)

        step add_connection.call(provider: PROVIDER, credentials: { access_token: }, **grant)
      end

      private

      def fetch_grant(**)
        Success(github.grant(**))
      rescue OAuth2::Error, Faraday::Error, KeyError
        Failure(:github_failed)
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module Operations
    class ConnectGitHub < ConnectOperation
      PROVIDER = Blog::Types::ServiceProvider["github"]

      include Deps[github: "github.auth"]

      def call(code:, redirect_uri:, code_verifier:)
        grant = step fetch_grant(code:, redirect_uri:, code_verifier:)
        access_token = grant.delete(:access_token)
        held = connection_queries.for(PROVIDER).find { it.account_id == grant[:account_id] }

        step save(held, credentials: { access_token: }, **grant)
      end

      private

      def fetch_grant(**)
        Success(github.grant(**))
      rescue Blog::ServiceError
        Failure(:github_failed)
      end
    end
  end
end

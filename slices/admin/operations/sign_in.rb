# frozen_string_literal: true

module Admin
  module Operations
    class SignIn < Blog::Operation
      include Deps["repos.owner_identity_queries"]

      def call(client:, code:, redirect_uri:, code_verifier:)
        email = step fetch_email(client:, code:, redirect_uri:, code_verifier:)
        step check_operator(email)
      end

      private

      def check_operator(email)
        owner_identity_queries.email?(email) ? Success(email.downcase) : Failure(:wrong_account)
      end

      def fetch_email(client:, code:, redirect_uri:, code_verifier:)
        Success(client.verified_email(code:, redirect_uri:, code_verifier:))
      rescue OAuth2::Error, Faraday::Error, KeyError, JSON::ParserError
        Failure(:provider_failed)
      end
    end
  end
end

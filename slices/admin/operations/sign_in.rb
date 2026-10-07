# frozen_string_literal: true

module Admin
  module Operations
    class SignIn < Operation
      include Deps["settings", github: "github.auth"]

      def call(code:, redirect_uri:)
        github_user_id = step fetch_github_user_id(code:, redirect_uri:)
        step check_operator(github_user_id)
      end

      private

      def check_operator(github_user_id)
        settings.operator?(github_user_id) ? Success(settings.owner[:github_id]) : Failure(:wrong_account)
      end

      def fetch_github_user_id(code:, redirect_uri:)
        Success(github.user_id(code:, redirect_uri:))
      rescue OAuth2::Error, Faraday::Error, KeyError
        Failure(:github_failed)
      end
    end
  end
end

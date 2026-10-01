# frozen_string_literal: true

module API
  module Operations
    class RevokeToken < Blog::Operation
      include Deps[token_repo: "repos.api_token_repo"]

      def call(id) = step revoke(id)

      private

      def revoke(id)
        token = token_repo.revoke(id)
        token ? Success(token) : Failure(:not_found)
      end
    end
  end
end

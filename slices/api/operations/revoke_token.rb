# frozen_string_literal: true

module API
  module Operations
    class RevokeToken < Operation
      include Deps[token_repo: "repos.api_token_repo"]

      def call(id) = step revoke(id)

      private

      def revoke(id)
        found(token_repo.revoke(id))
      end
    end
  end
end

# frozen_string_literal: true

module API
  module Operations
    class RevokeToken < Operation
      include Deps["repos.api_token_mutations"]

      def call(id) = step revoke(id)

      private

      def revoke(id)
        found(api_token_mutations.revoke(id))
      end
    end
  end
end

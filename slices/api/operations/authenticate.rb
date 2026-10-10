# frozen_string_literal: true

module API
  module Operations
    class Authenticate < Operation
      BEARER = /\ABearer +(?<token>\S+)\z/i
      INVALID_TOKEN = "invalid_token"
      NO_TOKEN = "this endpoint takes a bearer API token"
      UNUSABLE_TOKEN = "the API token is unknown, revoked or expired"

      include Deps["repos.api_token_mutations", "repos.api_token_queries"]

      def call(authorization)
        value = step read(authorization)
        token = step find(value)
        api_token_mutations.touch_last_used(token.id)
      end

      private

      def find(value)
        token = api_token_queries.live_by_token(value)
        token ? Success(token) : Failure({ error: INVALID_TOKEN, error_description: UNUSABLE_TOKEN })
      end

      def read(authorization)
        match = BEARER.match(authorization.to_s)
        match ? Success(match[:token]) : Failure({ error_description: NO_TOKEN })
      end
    end
  end
end

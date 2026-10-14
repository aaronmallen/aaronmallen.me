# frozen_string_literal: true

module API
  module Endpoints
    class ListAPITokens < Endpoint
      SCHEMA = { additionalProperties: false, properties: {} }.freeze
      REPLY = Helpers::Schema.object({ tokens: Helpers::Schema.list(Serializers::APIToken.reference) }).freeze

      include Deps["repos.api_token_queries"]

      def handle = Success(tokens: serialized(Serializers::APIToken, api_token_queries.live))
    end
  end
end

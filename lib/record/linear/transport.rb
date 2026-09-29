# frozen_string_literal: true

require "faraday"

module Record
  module Linear
    class Transport
      class Error < Record::Error; end
      class RateLimited < Record::RateLimited; end

      GRAPHQL_PATH = "/graphql"
      RATE_LIMITED_ERROR = "RATELIMITED"
      RATE_LIMIT_STATUS = 429

      def initialize(connection:)
        @connection = connection
      end

      def query(document, **variables)
        response = connection.post(GRAPHQL_PATH) { it.body = { query: document, variables: } }
        body = response.body.is_a?(Hash) ? response.body : Dry::Core::Constants::EMPTY_HASH

        data(response, body)
      rescue Faraday::Error => e
        raise Error, "Linear GraphQL request failed: #{e.message}"
      end

      private

      attr_reader :connection

      def data(response, body)
        errors = body["errors"].to_a
        raise RateLimited, "Linear rate limited GraphQL" if rate_limited?(response, errors)
        raise Error, "Linear answered GraphQL errors: #{errors.filter_map { it['message'] }.join(', ')}" if errors.any?
        raise Error, "Linear answered #{response.status} for GraphQL" unless response.success?

        body["data"]
      end

      def rate_limited?(response, errors)
        response.status == RATE_LIMIT_STATUS || errors.any? { it.dig("extensions", "code") == RATE_LIMITED_ERROR }
      end
    end
  end
end

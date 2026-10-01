# frozen_string_literal: true

require "faraday"
require "time"

module Record
  module GitHub
    class Transport
      class Error < Record::Error; end
      class RateLimited < Record::RateLimited; end

      EMPTY_STATUSES = [404, 410].freeze
      GRAPHQL_PATH = "/graphql"
      RATE_LIMITED_ERROR = "RATE_LIMITED"
      RATE_LIMIT_STATUSES = [403, 429].freeze
      SKIPPABLE_ERRORS = %w[FORBIDDEN NOT_FOUND].freeze

      attr_reader :rate_limit_remaining, :rate_limit_reset_at

      def initialize(connection:, graphql: nil)
        @connection = connection
        @graphql = graphql
        @rate_limit_remaining = nil
        @rate_limit_reset_at = nil
      end

      def configured? = !connection.nil?

      def get(path, **params)
        response = connection.get(path, params)

        return readable(response.body) if response.success?
        raise RateLimited, "GitHub rate limited #{path}" if rate_limited?(response)
        return nil if EMPTY_STATUSES.include?(response.status)

        raise Error, "GitHub answered #{response.status} for #{path}"
      rescue Faraday::Error => e
        raise Error, "GitHub request to #{path} failed: #{e.message}"
      end

      def query(document, **variables)
        body = post(document, variables)
        read_rate_limit(body.dig("data", "rateLimit"))

        data(body)
      rescue Faraday::Error => e
        raise Error, "GitHub GraphQL request failed: #{e.message}"
      end

      private

      attr_reader :connection, :graphql

      def data(body)
        errors = body["errors"].to_a
        raise RateLimited, "GitHub rate limited GraphQL" if errors.any? { it["type"] == RATE_LIMITED_ERROR }
        return body["data"] if errors.all? { SKIPPABLE_ERRORS.include?(it["type"]) }

        raise Error, "GitHub answered GraphQL errors: #{errors.filter_map { it['message'] }.join(', ')}"
      end

      def post(document, variables)
        response = graphql.post(GRAPHQL_PATH) { it.body = { query: document, variables: } }
        raise RateLimited, "GitHub rate limited GraphQL" if rate_limited?(response)
        raise Error, "GitHub answered #{response.status} for GraphQL" unless response.success?

        response.body.is_a?(Hash) ? response.body : Blog::Constants::EMPTY_HASH
      end

      def rate_limited?(response)
        return false unless RATE_LIMIT_STATUSES.include?(response.status)

        response.headers["x-ratelimit-remaining"] == "0" || response.headers.key?("retry-after")
      end

      def read_rate_limit(limit)
        return if limit.nil?

        @rate_limit_remaining = limit["remaining"].to_i if limit["remaining"]
        @rate_limit_reset_at = Time.iso8601(limit["resetAt"]) if limit["resetAt"]
      end

      def readable(body) = body.is_a?(Hash) ? body : nil
    end
  end
end

# frozen_string_literal: true

require "faraday"

module Social
  module Mastodon
    class Client
      class Error < Social::Error; end
      class RateLimited < Error; end

      IDEMPOTENCY_HEADER = "Idempotency-Key"
      LIMIT = 500
      MENTION = /@(\w[\w.-]*)@[\w-]+(?:\.[\w-]+)+/
      RESERVED_PER_URL = 23
      STATUSES_PATH = "/api/v1/statuses"
      TOO_MANY_REQUESTS = 429
      VISIBILITY = "public"

      def initialize(connection:)
        @connection = connection
      end

      def configured? = !connection.nil?

      def count(text) = countable(text).grapheme_clusters.size

      def engagement(id)
        return nil unless configured?

        body = request(:get, "#{STATUSES_PATH}/#{id}")

        Engagement.new(
          like_count: body["favourites_count"].to_i,
          reply_count: body["replies_count"].to_i,
          repost_count: body["reblogs_count"].to_i,
        )
      end

      def inspect = "#<#{self.class.name} configured=#{configured?}>"

      def limit = LIMIT

      def max_bytes = nil

      def post(text, idempotency_key:, reply_to: nil, **)
        body = request(
          :post, STATUSES_PATH, key: idempotency_key,
                                in_reply_to_id: reply_to, status: text, visibility: VISIBILITY,
        )
        id = body["id"] or raise Error, "Mastodon answered #{STATUSES_PATH} without a status ID"

        RemotePost.new(id: id.to_s, url: body["url"].to_s)
      end

      def within_limit?(text) = count(text) <= LIMIT

      private

      attr_reader :connection

      def countable(text)
        text.to_s.gsub(Links::PATTERN) { shrink(Regexp.last_match(0)) }.gsub(MENTION, "@\\1")
      end

      def error_message(route, response)
        return "Mastodon answered #{response.status} for #{route}" unless response.success?

        "Mastodon answered #{route} with #{response.body.class} instead of JSON"
      end

      def request(verb, path, key: nil, **payload)
        route = "#{verb.upcase} #{path}"
        response = send_request(verb, path, key, payload)

        return response.body if response.success? && response.body.is_a?(Hash)
        raise RateLimited, "Mastodon rate limited #{route}" if response.status == TOO_MANY_REQUESTS

        raise Error, error_message(route, response)
      rescue Faraday::Error, URI::Error => e
        raise Error, "Mastodon request #{route} failed: #{e.message}"
      end

      def send_request(verb, path, key, payload)
        connection.public_send(verb, path, payload.compact) do |http|
          http.headers[IDEMPOTENCY_HEADER] = key.to_s if key
        end
      end

      def shrink(match)
        url = Links.trim(match)

        ("x" * RESERVED_PER_URL) + match[url.length..]
      end
    end
  end
end

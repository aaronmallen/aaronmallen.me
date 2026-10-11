# frozen_string_literal: true

require "faraday"

module Social
  module Mastodon
    class Client
      class Error < Social::Error; end
      class RateLimited < Error; end

      IDEMPOTENCY_HEADER = "Idempotency-Key"
      IMAGE_SIZE_LIMIT = %w[configuration media_attachments image_size_limit].freeze
      INSTANCE_PATH = "/api/v2/instance"
      LIMIT = 500
      MEDIA_PATH = "/api/v2/media"
      MENTION = /@(\w[\w.-]*)@[\w-]+(?:\.[\w-]+)+/
      RESERVED_PER_URL = 23
      SEARCH_PATH = "/api/v2/search"
      STATUSES_PATH = "/api/v1/statuses"
      TOO_MANY_REQUESTS = 429
      VISIBILITY = "public"

      def initialize(account:, connect:, fit:, scan_links:)
        @account = account
        @connect = connect
        @fit = fit
        @scan_links = scan_links
      end

      def configured? = !(@current = @account.call).nil?

      def count(text) = countable(text).grapheme_clusters.size

      def engagement(id)
        return nil unless configured?

        body = request(:get, "#{STATUSES_PATH}/#{id}")

        Structs::Engagement.new(
          like_count: body["favourites_count"].to_i,
          reply_count: body["replies_count"].to_i,
          repost_count: body["reblogs_count"].to_i,
        )
      end

      def for(connection)
        account = [connection.host, connection.credentials.fetch(:access_token)]

        self.class.new(account: -> { account }, connect: @connect, fit: @fit, scan_links:)
      end

      def inspect = "#<#{self.class.name} configured=#{configured?}>"

      def limit = LIMIT

      def max_bytes = nil

      def post(text, idempotency_key:, reply_to: nil, photos: Blog::Constants::EMPTY_ARRAY, **)
        media_ids = photos.map { upload(it) }
        body = request(
          :post, STATUSES_PATH, key: idempotency_key,
                                in_reply_to_id: reply_to, media_ids: (media_ids unless media_ids.empty?),
                                status: text, visibility: VISIBILITY,
        )
        id = body["id"] or raise Error, "Mastodon answered #{STATUSES_PATH} without a status ID"

        Structs::RemotePost.new(id: id.to_s, url: body["url"].to_s)
      end

      def reserved_per_url = RESERVED_PER_URL

      def search(text, limit:)
        body = request(:get, SEARCH_PATH, q: text, type: "accounts", resolve: true, limit:)

        body["accounts"].to_a.map { account(it) }
      end

      def within_limit?(text) = count(text) <= LIMIT

      private

      attr_reader :scan_links

      def account(found)
        acct = found["acct"].to_s
        handle = acct.include?("@") ? acct : "#{acct}@#{connection.url_prefix.host}"

        Structs::Account.new(avatar: found["avatar"], handle: "@#{handle}", name: found["display_name"].to_s.strip)
      end

      def answered(route)
        response = yield

        return response.body if response.success? && response.body.is_a?(Hash)
        raise RateLimited, "Mastodon rate limited #{route}" if response.status == TOO_MANY_REQUESTS

        raise Error, error_message(route, response)
      rescue Faraday::Error, URI::Error => e
        raise Error, "Mastodon request #{route} failed: #{e.message}"
      end

      def connection
        current = @current || @account.call || raise(Error, "Mastodon is not connected")
        @connection = { account: current, http: @connect.call(*current) } unless @connection&.fetch(:account) == current
        @connection.fetch(:http)
      end

      def countable(text)
        scan_links.map(text) { "x" * RESERVED_PER_URL }.gsub(MENTION, "@\\1")
      end

      def error_message(route, response)
        return "Mastodon answered #{response.status} for #{route}" unless response.success?

        "Mastodon answered #{route} with #{response.body.class} instead of JSON"
      end

      def fitted(photo)
        limit = image_size_limit
        return photo.body unless limit.positive? && photo.body.bytesize > limit

        @fit.call(photo.body, photo.content_type, limit) || raise(Error, "A photo would not shrink to fit Mastodon")
      end

      def image_size_limit
        @image_size_limit ||= request(:get, INSTANCE_PATH).dig(*IMAGE_SIZE_LIMIT).to_i
      end

      def request(verb, path, key: nil, **payload)
        answered("#{verb.upcase} #{path}") { send_request(verb, path, key, payload) }
      end

      def send_request(verb, path, key, payload)
        connection.public_send(verb, path, payload.compact) do |http|
          http.headers[IDEMPOTENCY_HEADER] = key.to_s if key
        end
      end

      def upload(photo)
        form = Form.new(file: [fitted(photo), photo.content_type], description: photo.alt)
        body = answered("POST #{MEDIA_PATH}") do
          connection.post(MEDIA_PATH, form.body) { it.headers["Content-Type"] = form.content_type }
        end

        body.fetch("id") { raise Error, "Mastodon answered #{MEDIA_PATH} without a media ID" }.to_s
      end
    end
  end
end

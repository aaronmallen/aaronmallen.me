# frozen_string_literal: true

require "rack/utils"

module Social
  module Operations
    class CheckLink
      BROKEN_STATUSES = [404, 410, *500..599].freeze

      include Deps[client: "page_fetcher.link_check"]

      def call(url)
        status = client.fetch(url).status
        [status, Rack::Utils::HTTP_STATUS_CODES[status]].compact.join(" ") if BROKEN_STATUSES.include?(status)
      rescue PageFetcher::Client::TimedOut => e
        "Timed out after #{e.seconds} seconds"
      rescue PageFetcher::Client::Unreachable => e
        e.message
      rescue PageFetcher::Client::Error
        nil
      end
    end
  end
end

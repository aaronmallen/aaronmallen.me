# frozen_string_literal: true

require "rack/utils"

module Social
  module Operations
    class CheckLink
      BROKEN_STATUSES = [404, 410, *500..599].freeze

      include Deps[client: "webmentions.link_checker"]

      def call(url)
        status = client.fetch(url).status
        [status, Rack::Utils::HTTP_STATUS_CODES[status]].compact.join(" ") if BROKEN_STATUSES.include?(status)
      rescue Webmentions::Client::TimedOut => e
        "Timed out after #{e.seconds} seconds"
      rescue Webmentions::Client::Unreachable => e
        e.message
      rescue Webmentions::Client::Error
        nil
      end
    end
  end
end

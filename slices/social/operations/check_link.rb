# frozen_string_literal: true

module Social
  module Operations
    class CheckLink
      BROKEN_STATUSES = [404, 410].freeze

      include Deps[client: "webmentions.link_checker"]

      def call(url)
        status = client.fetch(url).status
        "HTTP #{status}" if BROKEN_STATUSES.include?(status)
      rescue Webmentions::Client::Unreachable => e
        e.message
      rescue Webmentions::Client::Error
        nil
      end
    end
  end
end

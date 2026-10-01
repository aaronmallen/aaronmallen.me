# frozen_string_literal: true

module Social
  module Bluesky
    module Failures
      EXPIRED = "ExpiredToken"
      REFUSED = 400
      TOO_MANY_REQUESTS = 429

      class << self
        def for(nsid, response)
          return Client::RateLimited.new("Bluesky rate limited #{nsid}") if response.status == TOO_MANY_REQUESTS
          return Client::Expired.new("Bluesky session expired for #{nsid}") if expired?(response.body)

          (response.status == REFUSED ? Client::Refused : Client::Error).new(message(nsid, response))
        end

        private

        def expired?(body) = body.is_a?(Hash) && body["error"] == EXPIRED

        def message(nsid, response)
          return "Bluesky answered #{nsid} with #{response.body.class} instead of JSON" if response.success?

          ["Bluesky answered #{response.status} for #{nsid}", *reason(response.body)].join(": ")
        end

        def reason(body)
          return [] unless body.is_a?(Hash)

          body.values_at("error", "message").map { it.to_s.strip }.reject(&:empty?)
        end
      end
    end
  end
end

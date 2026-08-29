# frozen_string_literal: true

module Social
  module Providers
    module WebmentionsProvider
      AGENT = "webmention"
      HEADERS = { "Accept" => "text/html, text/*;q=0.9, */*;q=0.8" }.freeze

      class << self
        def build(http) = Webmentions::Client.new(connection: connection(http))

        private

        def connection(http)
          http.call(agent: AGENT, headers: HEADERS, redirects: 0) do |faraday|
            faraday.request :url_encoded
            faraday.adapter Webmentions::PinnedAddress
          end
        end
      end
    end
  end
end

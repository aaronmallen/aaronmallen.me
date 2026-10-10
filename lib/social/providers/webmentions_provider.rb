# frozen_string_literal: true

module Social
  module Providers
    module WebmentionsProvider
      AGENT = "webmention"
      LINK_CHECK_AGENT = "link-check"
      HEADERS = { "Accept" => "text/html, text/*;q=0.9, */*;q=0.8" }.freeze

      class << self
        def build(http, agent: AGENT) = Webmentions::Client.new(connection: connection(http, agent))

        private

        def connection(http, agent)
          http.call(agent:, headers: HEADERS, redirects: 0) do |faraday|
            faraday.request :url_encoded
            faraday.adapter Webmentions::PinnedAddress
          end
        end
      end
    end
  end
end

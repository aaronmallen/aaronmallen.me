# frozen_string_literal: true

module PageFetcher
  module Provider
    HEADERS = { "Accept" => "text/html, text/*;q=0.9, */*;q=0.8" }.freeze

    class << self
      def build(http, agent:, max_body: Client::MAX_BODY) = Client.new(connection: connection(http, agent), max_body:)

      private

      def connection(http, agent)
        http.call(agent:, headers: HEADERS, redirects: 0) do |faraday|
          faraday.request :url_encoded
          faraday.adapter PinnedAddress
        end
      end
    end
  end
end

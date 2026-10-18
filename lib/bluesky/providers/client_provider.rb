# frozen_string_literal: true

require "faraday"

module Bluesky
  module Providers
    module ClientProvider
      HEADERS = { "Accept" => "application/json" }.freeze
      PDS_URL = "https://bsky.social"
      PUBLIC_URL = "https://public.api.bsky.app"

      class << self
        def client(http, pages)
          Client.new(pages:, pds: json(http, PDS_URL), public_api: json(http, PUBLIC_URL))
        end

        private

        def json(http, url)
          http.call(headers: HEADERS, url:, params_encoder: Faraday::FlatParamsEncoder) do |faraday|
            faraday.request :json
            faraday.response :json
          end
        end
      end
    end
  end
end

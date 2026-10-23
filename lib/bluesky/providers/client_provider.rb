# frozen_string_literal: true

require "faraday"

module Bluesky
  module Providers
    module ClientProvider
      HEADERS = { "Accept" => "application/json" }.freeze

      class << self
        def client(settings, http, pages)
          bluesky = settings.bluesky

          Client.new(pages:, pds: json(http, bluesky[:pds_url]), public_api: json(http, bluesky[:public_url]))
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

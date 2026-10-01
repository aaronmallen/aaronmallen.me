# frozen_string_literal: true

require "faraday"
require "uri"

module Social
  module Providers
    module NetworksProvider
      HEADERS = { "Accept" => "application/json" }.freeze
      PDS_URL = "https://bsky.social"
      PUBLIC_URL = "https://public.api.bsky.app"

      class << self
        def all(bluesky, mastodon)
          { Blog::Types::NetworkName["bluesky"] => bluesky, Blog::Types::NetworkName["mastodon"] => mastodon }.freeze
        end

        def bluesky(settings, http)
          handle, password = credentials(settings.bluesky, :handle, :app_password)

          Bluesky::Client.new(
            handle:, password:,
            pds: json(http, url: PDS_URL, params_encoder: Faraday::FlatParamsEncoder),
            public_api: json(http, url: PUBLIC_URL, params_encoder: Faraday::FlatParamsEncoder),
          )
        end

        def mastodon(settings, http)
          url, token = credentials(settings.mastodon, :url, :access_token)

          Mastodon::Client.new(connection: url && json(http, url:, headers: bearer(token)))
        rescue URI::Error
          Mastodon::Client.new(connection: nil)
        end

        private

        def bearer(token) = { "Authorization" => "Bearer #{token}" }

        def credentials(settings, *keys)
          found = settings.values_at(*keys)

          found.all? ? found : Array.new(found.size)
        end

        def json(http, headers: Blog::Constants::EMPTY_HASH, **)
          http.call(headers: HEADERS.merge(headers), **) do |faraday|
            faraday.request :json
            faraday.response :json
          end
        end
      end
    end
  end
end

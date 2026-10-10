# frozen_string_literal: true

require "faraday"

module Social
  module Providers
    module NetworksProvider
      HEADERS = { "Accept" => "application/json" }.freeze
      MASTODON = Blog::Types::ServiceProvider["mastodon"]
      PDS_URL = "https://bsky.social"
      PUBLIC_URL = "https://public.api.bsky.app"

      class << self
        def all(bluesky, mastodon)
          { Blog::Types::NetworkName["bluesky"] => bluesky, Blog::Types::NetworkName["mastodon"] => mastodon }.freeze
        end

        def bluesky(connections, http, scan_links:, scan_tags:)
          Bluesky::Client.new(
            connections:, scan_links:, scan_tags:,
            pds: json(http, url: PDS_URL, params_encoder: Faraday::FlatParamsEncoder),
            public_api: json(http, url: PUBLIC_URL, params_encoder: Faraday::FlatParamsEncoder),
          )
        end

        def mastodon(connection_queries, http, scan_links:)
          account = lambda do
            found = connection_queries.for(MASTODON).first
            found && [found.host, found.credentials.fetch(:access_token)]
          end
          connect = ->(host, token) { json(http, url: "https://#{host}", headers: bearer(token)) }

          Mastodon::Client.new(account:, connect:, scan_links:)
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

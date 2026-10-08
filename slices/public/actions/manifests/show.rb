# frozen_string_literal: true

require "json"

module Public
  module Actions
    module Manifests
      class Show < Action
        ICONS = { "icon-192.png" => "192x192", "icon-512.png" => "512x512" }.freeze
        ICON_TYPE = "image/png"
        MEDIA_TYPE = "application/manifest+json"

        include Deps["assets"]

        config.formats.clear.accept :webmanifest
        answer_any_accept :webmanifest, MEDIA_TYPE

        def handle(_request, response)
          response.body = JSON.generate(manifest)
        end

        private

        def icons = ICONS.map { |source, sizes| { src: assets[source].url, sizes:, type: ICON_TYPE } }

        def manifest
          name = Hanami.app.settings.owner_name
          { name:, short_name: name, start_url: "/", display: "minimal-ui", icons: }
        end
      end
    end
  end
end

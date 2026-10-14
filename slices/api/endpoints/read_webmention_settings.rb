# frozen_string_literal: true

module API
  module Endpoints
    class ReadWebmentionSettings < WebmentionSettingsEndpoint
      SCHEMA = { additionalProperties: false, properties: {} }.freeze

      include Deps[webmention_queries: "social.repos.webmention_queries"]

      def handle = answered(webmention_queries.settings)
    end
  end
end

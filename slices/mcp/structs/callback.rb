# frozen_string_literal: true

require "rack/utils"
require "uri"

module MCP
  module Structs
    Callback = Data.define(:issuer, :redirect_uri, :state) do
      def error(error, description) = url(error:, error_description: description)

      def granted(code) = url(code:)

      private

      def url(**answer)
        uri = URI.parse(redirect_uri)
        given = Rack::Utils.parse_query(uri.query)
        ours = { "iss" => issuer, "state" => state, **answer.transform_keys(&:to_s) }.compact
        uri.query = Rack::Utils.build_query(given.merge(ours))
        uri.to_s
      end
    end
  end
end

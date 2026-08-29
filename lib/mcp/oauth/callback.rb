# frozen_string_literal: true

require "rack/utils"
require "uri"

module MCP
  module OAuth
    class Callback
      def initialize(issuer:, redirect_uri:, state:)
        @issuer = issuer
        @redirect_uri = redirect_uri
        @state = state
      end

      def error(error, description) = url(error:, error_description: description)

      def granted(code) = url(code:)

      private

      def url(**answer)
        uri = URI.parse(@redirect_uri)
        given = Rack::Utils.parse_query(uri.query)
        ours = { "iss" => @issuer, "state" => @state, **answer.transform_keys(&:to_s) }.compact
        uri.query = Rack::Utils.build_query(given.merge(ours))
        uri.to_s
      end
    end
  end
end

# frozen_string_literal: true

require "multi_xml"

module Admin
  module Operations
    class ConnectLinkedIn < Blog::Operation
      PROVIDER = Blog::Types::ServiceProvider["linkedin"]

      include Deps[add_connection: "services.operations.add_connection", linkedin: "linkedin.auth"]

      def call(code:, redirect_uri:)
        grant = step fetch_grant(code:, redirect_uri:)

        step add_connection.call(provider: PROVIDER, **grant)
      end

      private

      def fetch_grant(**)
        Success(linkedin.grant(**))
      rescue OAuth2::Error, Faraday::Error, KeyError, JSON::ParserError, MultiXML::ParseError
        Failure(:linkedin_failed)
      end
    end
  end
end

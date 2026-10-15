# frozen_string_literal: true

require "multi_xml"

module Admin
  module Operations
    class ConnectLinkedIn < ConnectOperation
      PROVIDER = Blog::Types::ServiceProvider["linkedin"]

      include Deps[linkedin: "linkedin.auth"]

      def call(code:, redirect_uri:)
        grant = step fetch_grant(code:, redirect_uri:)
        lapses_at = grant[:credentials][:expires_at]&.then { Time.at(it) }

        step save(connection_queries.for(PROVIDER).find { it.account_id == grant[:account_id] }, **grant, lapses_at:)
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

# frozen_string_literal: true

require "json"
require "multi_xml"
require "oauth2"

module Blog
  class ServiceError < StandardError
    OAUTH_FAILURES = [OAuth2::Error, Faraday::Error, KeyError, JSON::ParserError, MultiXML::ParseError].freeze
  end
end

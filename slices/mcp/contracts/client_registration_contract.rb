# frozen_string_literal: true

module MCP
  module Contracts
    class ClientRegistrationContract < Blog::Contract
      MAX_NAME = 200
      MAX_REDIRECT_URIS = 10
      MAX_URI = 2048
      REDIRECT_URI = Blog::Types::String.constructor do |value|
        Blog::Types::RedirectUri.call(value) { Blog::Constants::EMPTY_STRING }
      end

      json do
        required(:redirect_uris).value(:array?, size?: 1..MAX_REDIRECT_URIS).array(REDIRECT_URI, :filled?)
        optional(:client_name).maybe(Blog::Types::OptionalText, max_size?: MAX_NAME)
        optional(:client_uri).maybe(Blog::Types::OptionalText, max_size?: MAX_URI)
        optional(:logo_uri).maybe(Blog::Types::OptionalText, max_size?: MAX_URI)
      end

      rule(:client_name).validate(:without_controls)
      rule(:client_uri).validate(:without_controls)
      rule(:logo_uri).validate(:without_controls)
    end
  end
end

# frozen_string_literal: true

module MCP
  module Contracts
    class AuthorizationRequestContract < Blog::Contract
      FOREIGN = "foreign"
      UNCOERCED = Blog::Types::String.optional
      SCOPE_TOKEN = /[\x21\x23-\x5B\x5D-\x7E]+/
      SCOPE = /\A#{SCOPE_TOKEN}(?: #{SCOPE_TOKEN})*\z/
      STATE = /\A[\x20-\x7E]*\z/

      params do
        required(:response_type).filled(:string, included_in?: OAuth::Metadata::RESPONSE_TYPES)
        required(:code_challenge).filled(:string, format?: OAuth::PKCE::SHAPE)
        optional(:code_challenge_method).value(UNCOERCED) { nil? | eql?(OAuth::PKCE::METHOD) }
        optional(:redirect_uri).value(UNCOERCED)
        optional(:resource).value(UNCOERCED)
        optional(:scope).maybe(:string, format?: SCOPE)
        optional(:state).value(UNCOERCED) { nil? | format?(STATE) }
      end

      rule(:resource) do |context:|
        key.failure(FOREIGN) unless OAuth::Resource.ours?(value, context[:issuer])
      end
    end
  end
end

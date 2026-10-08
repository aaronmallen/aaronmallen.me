# frozen_string_literal: true

module MCP
  module Contracts
    class AuthorizationRequestContract < Blog::Contract
      FOREIGN = "foreign"
      UNCOERCED = Blog::Types::String.optional
      SCOPE_TOKEN = /[\x21\x23-\x5B\x5D-\x7E]+/
      SCOPE = /\A#{SCOPE_TOKEN}(?: #{SCOPE_TOKEN})*\z/
      STATE = /\A[\x20-\x7E]*\z/

      include Deps["operations.match_resource"]

      params do
        required(:response_type).filled(:string, included_in?: Blog::Types::OAuthResponseType.values)
        required(:code_challenge).filled(Blog::Types::PKCEValue)
        optional(:code_challenge_method).value(Blog::Types::CodeChallengeMethod.optional)
        optional(:redirect_uri).value(UNCOERCED)
        optional(:resource).value(UNCOERCED)
        optional(:scope).maybe(:string, format?: SCOPE)
        optional(:state).value(UNCOERCED) { nil? | format?(STATE) }
      end

      rule(:resource) do |context:|
        key.failure(FOREIGN) unless match_resource.call(value, context[:issuer])
      end
    end
  end
end

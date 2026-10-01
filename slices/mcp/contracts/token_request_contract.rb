# frozen_string_literal: true

module MCP
  module Contracts
    class TokenRequestContract < Blog::Contract
      AUTHORIZATION_CODE = "authorization_code"
      MISSING = "missing"
      REFRESH_TOKEN = "refresh_token"
      NEEDED = {
        AUTHORIZATION_CODE => %i[code code_verifier],
        REFRESH_TOKEN => %i[refresh_token],
      }.freeze

      params do
        required(:grant_type).filled(:string, included_in?: OAuth::Metadata::GRANT_TYPES)
        optional(:code).maybe(:string, format?: OAuth::Secret::SHAPE)
        optional(:refresh_token).maybe(:string, format?: OAuth::Secret::SHAPE)
        optional(:code_verifier).maybe(:string, format?: OAuth::PKCE::SHAPE)
        optional(:redirect_uri).maybe(:string)
      end

      rule(:redirect_uri).validate(:without_controls)

      NEEDED.values.flatten.each do |field|
        rule(:grant_type, field) do
          key(field).failure(MISSING) if values[field].nil? && NEEDED[values[:grant_type]].include?(field)
        end
      end
    end
  end
end

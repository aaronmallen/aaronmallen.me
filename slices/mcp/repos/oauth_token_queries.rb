# frozen_string_literal: true

module MCP
  module Repos
    class OAuthTokenQueries < Blog::DB::Repo
      def by_token(token, type:) = oauth_tokens.of_type(type).with_digest(Blog::Types::SecretDigest[token]).one
    end
  end
end

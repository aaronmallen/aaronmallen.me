# frozen_string_literal: true

module MCP
  module Repos
    class OAuthCodeQueries < Blog::DB::Repo
      def by_code(code) = oauth_codes.with_digest(Blog::Types::SecretDigest[code]).one
    end
  end
end

# frozen_string_literal: true

module MCP
  module Repos
    class OAuthCodeQueries < DB::Repo
      def by_code(code) = oauth_codes.with_digest(Blog::SecretToken.digest(code)).one
    end
  end
end

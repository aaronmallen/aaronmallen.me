# frozen_string_literal: true

module API
  module Repos
    class APITokenQueries < DB::Repo
      def live = api_tokens.live.newest_first.to_a

      def live_by_token(token) = api_tokens.live.with_digest(Blog::Types::SecretDigest[token]).one
    end
  end
end

# frozen_string_literal: true

module API
  module Relations
    class APITokens < Blog::DB::Relation
      schema :api_tokens, infer: true

      def last_used_before(time) = where(Sequel.|({ last_used_at: nil }, Sequel[:last_used_at] < time))

      def live(at: Time.now) = where(revoked_at: nil).where { expires_at.is(nil) | (expires_at > at) }

      def with_digest(token_digest) = where(token_digest:)
    end
  end
end

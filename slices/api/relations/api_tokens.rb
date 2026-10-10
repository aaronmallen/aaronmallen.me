# frozen_string_literal: true

module API
  module Relations
    class APITokens < Blog::DB::Relation
      schema :api_tokens, infer: true

      def live(at: Time.now) = where(revoked_at: nil).where { expires_at.is(nil) | (expires_at > at) }

      def newest_first = order(self[:created_at].desc, self[:id].desc)

      def with_digest(token_digest) = where(token_digest:)
    end
  end
end

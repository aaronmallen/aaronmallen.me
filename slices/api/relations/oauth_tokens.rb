# frozen_string_literal: true

module API
  module Relations
    class OAuthTokens < Blog::DB::Relation
      schema :oauth_tokens, infer: true

      def live(at: Time.now) = where(revoked_at: nil).where { expires_at > at }

      def live_for(oauth_client_ids, at: Time.now) = live(at:).where(oauth_client_id: oauth_client_ids)
    end
  end
end

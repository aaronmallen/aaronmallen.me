# frozen_string_literal: true

module MCP
  module Relations
    class OAuthTokens < Blog::DB::Relation
      schema :oauth_tokens, infer: true

      def burn(id, at: Time.now) = live.by_pk(id).stamped(:update).call(revoked_at: at)

      def expired(at: Time.now) = where { expires_at <= at }

      def for_client(oauth_client_id) = where(oauth_client_id:)

      def live = where(revoked_at: nil)

      def of_type(type) = where(type:)

      def unexpired(at: Time.now) = where { expires_at > at }

      def with_digest(token_digest) = where(token_digest:)
    end
  end
end

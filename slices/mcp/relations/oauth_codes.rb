# frozen_string_literal: true

module MCP
  module Relations
    class OAuthCodes < Blog::DB::Relation
      schema :oauth_codes, infer: true

      def burn(id, at: Time.now) = unused.by_pk(id).stamped(:update).call(used_at: at)

      def expired(at: Time.now) = where { expires_at <= at }

      def for_client(oauth_client_id) = where(oauth_client_id:)

      def unused = where(used_at: nil)

      def with_digest(code_digest) = where(code_digest:)
    end
  end
end

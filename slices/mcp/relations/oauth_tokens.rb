# frozen_string_literal: true

module MCP
  module Relations
    class OAuthTokens < Blog::DB::Relation
      CLIENT_LAST_USED = Sequel[:oauth_clients][:last_used_at]

      schema :oauth_tokens, infer: true

      def burn(id, at: Time.now) = live.by_pk(id).stamped(:update).call(revoked_at: at)

      def expired(at: Time.now) = where { expires_at <= at }

      def for_client(oauth_client_id) = where(oauth_client_id:)

      def live = where(revoked_at: nil)

      def of_type(type) = where(type:)

      def with_client
        last_used = ROM::SQL::Attribute[ROM::Types::Time.optional].meta(sql_expr: CLIENT_LAST_USED)

        new(dataset.join(:oauth_clients, id: :oauth_client_id)).select_append(last_used.as(:client_last_used_at))
      end

      def with_digest(token_digest) = where(token_digest:)
    end
  end
end

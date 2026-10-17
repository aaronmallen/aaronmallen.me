# frozen_string_literal: true

module API
  module Relations
    class OAuthClients < Blog::DB::Relation
      schema :oauth_clients, infer: true

      def holding_live_token(oauth_tokens, at: Time.now) = holding_token(oauth_tokens.live(at:))

      def holding_scope(oauth_tokens, scope, at: Time.now)
        holding_token(oauth_tokens.live(at:).where(Sequel.expr(scope => Sequel.pg_array_op(:scopes).any)))
      end

      private

      def holding_token(tokens) = where(id: tokens.select(:oauth_client_id).dataset)
    end
  end
end

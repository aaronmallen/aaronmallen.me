# frozen_string_literal: true

module API
  module Relations
    class OAuthClients < Blog::DB::Relation
      schema :oauth_clients, infer: true

      def holding_live_token(at: Time.now)
        live = dataset.db[:oauth_tokens].where(revoked_at: nil).where { expires_at > at }

        where(id: live.select(:oauth_client_id))
      end
    end
  end
end

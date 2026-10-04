# frozen_string_literal: true

module MCP
  module Relations
    class OAuthClients < Blog::DB::Relation
      TABLE_KEY = Sequel.function(:hashtext, "oauth_clients")

      schema :oauth_clients, infer: true do
        attribute :visitor_hash, Blog::Types::VisitorHash
      end

      def claim(visitor_hash:, limit:, total_limit:, since:, **attrs)
        transaction do
          lock_table_until_commit
          fresh = registered_since(since)
          next unless fresh.for_visitor(visitor_hash).count < limit && fresh.count < total_limit

          stamped(:create).call(**attrs, visitor_hash:)
        end
      end

      def connected = where(revoked_at: nil)

      def for_visitor(visitor_hash) = where(visitor_hash:)

      def held_token
        where(Sequel.|(Sequel.~(last_used_at: nil), { id: dataset.db[:oauth_tokens].select(:oauth_client_id) }))
      end

      def holding_live_token(at: Time.now) = where(id: live_tokens(at).select(:oauth_client_id))

      def idle(since:, at: Time.now)
        exclude(id: live_tokens(at).select(:oauth_client_id))
          .exclude(id: live_codes(at).select(:oauth_client_id))
          .where { coalesce(last_used_at, created_at) < since }
      end

      def last_used_before(time) = where(Sequel.|({ last_used_at: nil }, Sequel[:last_used_at] < time))

      def newest_first = order(self[:created_at].desc, self[:id].desc)

      def registered_since(time) = where { created_at >= time }

      def unclaimed(since:)
        where(last_used_at: nil)
          .exclude(id: dataset.db[:oauth_codes].select(:oauth_client_id))
          .exclude(id: dataset.db[:oauth_tokens].select(:oauth_client_id))
          .where { created_at < since }
      end

      def with_client_id(client_id) = where(client_id:)

      private

      def live_codes(at) = dataset.db[:oauth_codes].where(used_at: nil).where { expires_at > at }

      def live_tokens(at) = dataset.db[:oauth_tokens].where(revoked_at: nil).where { expires_at > at }

      def lock_table_until_commit = dataset.db.get(Sequel.function(:pg_advisory_xact_lock, TABLE_KEY))
    end
  end
end

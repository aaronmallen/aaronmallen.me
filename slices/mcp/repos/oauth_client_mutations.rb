# frozen_string_literal: true

module MCP
  module Repos
    class OAuthClientMutations < Blog::DB::Repo
      root :oauth_clients

      def claim(visitor_hashes:, limit:, total_limit:, since:, **attrs)
        oauth_clients.claim(visitor_hashes:, limit:, total_limit:, since:, **attrs)
      end

      def delete_idle(since:, at: Time.now) = delete_locked(oauth_clients.idle(since:, at:))

      def delete_unclaimed(since:) = delete_locked(oauth_clients.unclaimed(since:))

      def touch_last_used(id, at: Time.now, unless_since: at)
        oauth_clients.by_pk(id).last_used_before(unless_since).update(last_used_at: at)
      end

      private

      def delete_locked(clients)
        transaction do
          locked = clients.lock.pluck(:id)
          clients.where(id: locked).delete
        end
      end
    end
  end
end

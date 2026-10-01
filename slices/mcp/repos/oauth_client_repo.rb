# frozen_string_literal: true

module MCP
  module Repos
    class OAuthClientRepo < Blog::DB::Repo
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def claim(visitor_hash:, limit:, since:, **attrs)
        oauth_clients.claim(visitor_hash:, limit:, since:, **attrs)
      end

      def connected = oauth_clients.connected.holding_live_token.newest_first.to_a

      def connected_by_client_id(client_id) = oauth_clients.connected.with_client_id(client_id).one

      def connected_by_id(id) = oauth_clients.connected.by_pk(id).one

      def connected_by_id_for_update(id) = oauth_clients.connected.by_pk(id).lock.one

      def count_from_visitor_since(visitor_hash, time)
        oauth_clients.for_visitor(visitor_hash).registered_since(time).count
      end

      def delete_idle(since:, at: Time.now)
        transaction do
          locked = oauth_clients.idle(since:, at:).lock.pluck(:id)
          oauth_clients.idle(since:, at:).where(id: locked).delete
        end
      end

      def touch_last_used(id, at: Time.now) = update(id, last_used_at: at)
    end
  end
end

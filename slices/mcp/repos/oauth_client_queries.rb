# frozen_string_literal: true

module MCP
  module Repos
    class OAuthClientQueries < Blog::DB::Repo
      def connected = oauth_clients.holding_live_token.newest_first.to_a

      def connected_by_client_id(client_id) = oauth_clients.with_client_id(client_id).one

      def connected_by_id(id) = oauth_clients.by_pk(id).one

      def connected_by_id_for_update(id) = oauth_clients.by_pk(id).lock.one

      def count_from_visitor_since(visitor_hashes, time)
        oauth_clients.for_visitor(visitor_hashes).registered_since(time).count
      end

      def count_since(time) = oauth_clients.registered_since(time).count

      def held_token?(id) = oauth_clients.by_pk(id).held_token.exist?
    end
  end
end

# frozen_string_literal: true

module API
  module Repos
    class ClientQueries < Blog::DB::Repo
      def connected = oauth_clients.holding_live_token.newest_first.to_a

      def granted_scopes(oauth_client_ids)
        held = oauth_tokens.live_for(oauth_client_ids).pluck(:oauth_client_id, :scopes).group_by(&:first)

        oauth_client_ids.to_h do |id|
          [id, Blog::Types::OAuthScope.values & held.fetch(id, Blog::Constants::EMPTY_ARRAY).flat_map { it.last.to_a }]
        end
      end
    end
  end
end

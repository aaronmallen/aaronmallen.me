# frozen_string_literal: true

module MCP
  module Repos
    class OAuthTokenQueries < DB::Repo
      def by_token(token, type:) = oauth_tokens.of_type(type).with_digest(Blog::SecretToken.digest(token)).one

      def granted_scopes(oauth_client_ids, at: Time.now)
        live = oauth_tokens.for_client(oauth_client_ids).live.unexpired(at:)
        held = live.pluck(:oauth_client_id, :scopes).group_by(&:first)

        oauth_client_ids.to_h do |id|
          [id, OAuth::Scope::ALL & held.fetch(id, Blog::Constants::EMPTY_ARRAY).flat_map { it.last.to_a }]
        end
      end
    end
  end
end

# frozen_string_literal: true

module MCP
  module Queries
    class GrantedScopes
      include Deps[token_repo: "repos.oauth_token_repo"]

      def call(oauth_client_ids)
        held = token_repo.live_scopes(oauth_client_ids).group_by(&:first)

        oauth_client_ids.to_h do |id|
          [id, OAuth::Scope::ALL & held.fetch(id, Blog::Constants::EMPTY_ARRAY).flat_map { it.last.to_a }]
        end
      end
    end
  end
end

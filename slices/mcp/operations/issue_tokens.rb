# frozen_string_literal: true

module MCP
  module Operations
    class IssueTokens < Blog::Operation
      ACCESS_LIFETIME = 60 * 60
      BEARER = "Bearer"
      REFRESH_LIFETIME = 30 * 24 * 60 * 60

      include Deps[token_repo: "repos.oauth_token_repo"]

      def call(oauth_client_id:, resource:, scopes:)
        held = { oauth_client_id:, resource:, scopes: }

        transaction do
          access_token, access = issue(Repos::OAuthTokenRepo::ACCESS, ACCESS_LIFETIME, **held)
          refresh_token, = issue(Repos::OAuthTokenRepo::REFRESH, REFRESH_LIFETIME, access_token_id: access.id, **held)

          {
            access_token:,
            expires_in: ACCESS_LIFETIME,
            refresh_token:,
            scope: scopes.join(OAuth::Scope::SEPARATOR),
            token_type: BEARER,
          }
        end
      end

      private

      def issue(type, lifetime, **held)
        token = Blog::SecretToken.generate

        [token, token_repo.issue(token:, type:, expires_at: Time.now + lifetime, **held)]
      end
    end
  end
end

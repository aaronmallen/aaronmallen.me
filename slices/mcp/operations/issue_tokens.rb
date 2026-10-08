# frozen_string_literal: true

module MCP
  module Operations
    class IssueTokens < Operation
      ACCESS_LIFETIME = 60 * 60
      BEARER = "Bearer"
      REFRESH_LIFETIME = 30 * 24 * 60 * 60

      include Deps["repos.oauth_token_mutations"]

      def call(oauth_client_id:, resource:, scopes:)
        held = { oauth_client_id:, resource:, scopes: }

        transaction do
          access_token, access = issue("access", ACCESS_LIFETIME, **held)
          refresh_token, = issue("refresh", REFRESH_LIFETIME, access_token_id: access.id, **held)

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
        token = Blog::Types::NewSecret[]
        expires_at = Time.now + lifetime

        [token, oauth_token_mutations.issue(token:, type: Blog::Types::OAuthTokenType[type], expires_at:, **held)]
      end
    end
  end
end

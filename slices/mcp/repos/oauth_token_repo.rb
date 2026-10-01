# frozen_string_literal: true

module MCP
  module Repos
    class OAuthTokenRepo < Blog::DB::Repo
      ACCESS = "access"
      REFRESH = "refresh"

      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }

      def by_token(token, type:) = oauth_tokens.of_type(type).with_digest(OAuth::Secret.digest(token)).one

      def delete_expired(at: Time.now) = oauth_tokens.expired(at:).delete

      def delete_for_client(oauth_client_id) = oauth_tokens.for_client(oauth_client_id).delete

      def issue(token:, **attributes) = create(token_digest: OAuth::Secret.digest(token), **attributes)

      def revoke(id, at: Time.now)
        oauth_tokens.burn(id, at:)&.tap do |token|
          oauth_tokens.burn(token[:access_token_id], at:) if token[:access_token_id]
        end
      end

      def revoke_for_client(oauth_client_id, at: Time.now)
        oauth_tokens.for_client(oauth_client_id).live.stamped(:update, result: :many).call(revoked_at: at)
      end
    end
  end
end

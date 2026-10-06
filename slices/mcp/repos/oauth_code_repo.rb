# frozen_string_literal: true

module MCP
  module Repos
    class OAuthCodeRepo < Blog::DB::Repo
      stamped_commands :create

      def burn(id, at: Time.now) = oauth_codes.burn(id, at:)

      def by_code(code) = oauth_codes.with_digest(Blog::SecretToken.digest(code)).one

      def delete_expired(at: Time.now) = oauth_codes.expired(at:).delete

      def delete_for_client(oauth_client_id) = oauth_codes.for_client(oauth_client_id).delete

      def issue(code:, **attributes) = create(code_digest: Blog::SecretToken.digest(code), **attributes)
    end
  end
end

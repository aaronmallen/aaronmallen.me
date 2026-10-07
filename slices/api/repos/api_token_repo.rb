# frozen_string_literal: true

module API
  module Repos
    class APITokenRepo < DB::Repo
      stamped_commands :create, :update

      def live = api_tokens.live.newest_first.to_a

      def live_by_token(token) = api_tokens.live.with_digest(Blog::SecretToken.digest(token)).one

      def mint(token:, name:) = create(name:, token_digest: Blog::SecretToken.digest(token))

      def revoke(id, at: Time.now) = (update(id, revoked_at: at) if api_tokens.live.by_pk(id).exist?)

      def touch_last_used(id, at: Time.now) = update(id, last_used_at: at)
    end
  end
end

# frozen_string_literal: true

module API
  module Repos
    class APITokenRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def live = api_tokens.live.newest_first.to_a

      def live_by_token(token) = api_tokens.live.with_digest(Blog::SecretToken.digest(token)).one

      def mint(token:, name:) = create(name:, token_digest: Blog::SecretToken.digest(token))

      def revoke(id, at: Time.now) = (update(id, revoked_at: at) if api_tokens.live.by_pk(id).exist?)

      def touch_last_used(id, at: Time.now) = update(id, last_used_at: at)
    end
  end
end

# frozen_string_literal: true

module API
  module Repos
    class APITokenMutations < Blog::DB::Repo
      root :api_tokens

      stamped_commands :create, :update

      def mint(token:, **fields) = create(**fields, token_digest: Blog::Types::SecretDigest[token])

      def revoke(id, at: Time.now) = (update(id, revoked_at: at) if api_tokens.live.by_pk(id).exist?)

      def touch_last_used(id, at: Time.now, unless_since: at)
        api_tokens.by_pk(id).last_used_before(unless_since).command(:update, result: :one).call(last_used_at: at)
      end
    end
  end
end

# frozen_string_literal: true

module Security
  module Repos
    class SignInMutations < Blog::DB::Repo
      root :sign_ins

      commands :create

      def claim_failure(...) = sign_ins.claim_failure(...)

      def delete_before(time) = sign_ins.created_before(time).delete

      def dismiss(id) = id ? sign_ins.failed.where(id:, dismissed_at: nil).update(dismissed_at: Time.now) : 0
    end
  end
end

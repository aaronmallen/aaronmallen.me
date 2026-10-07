# frozen_string_literal: true

module Security
  module Repos
    class SignInMutations < DB::Repo
      root :sign_ins

      commands :create

      def delete_before(time) = sign_ins.created_before(time).delete
    end
  end
end

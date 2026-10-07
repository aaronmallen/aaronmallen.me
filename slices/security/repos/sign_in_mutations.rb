# frozen_string_literal: true

module Security
  module Repos
    class SignInMutations < DB::Repo
      root :sign_ins

      commands :create
    end
  end
end

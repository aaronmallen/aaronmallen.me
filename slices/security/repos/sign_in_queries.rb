# frozen_string_literal: true

module Security
  module Repos
    class SignInQueries < Blog::DB::Repo
      def newest_first = sign_ins.newest_first.to_a
    end
  end
end

# frozen_string_literal: true

module Posts
  module Queries
    class CountDatedBetween
      include Deps[post_repo: "repos.post_repo"]

      def call(from:, to:) = post_repo.count_dated_between(from:, to:)
    end
  end
end

# frozen_string_literal: true

module Record
  module Queries
    class CommitsBetween
      include Deps[commit_repo: "repos.commit_repo"]

      def call(from:, to:, **) = commit_repo.between(from:, to:, **)
    end
  end
end

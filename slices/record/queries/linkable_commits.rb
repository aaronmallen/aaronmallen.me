# frozen_string_literal: true

module Record
  module Queries
    class LinkableCommits
      include Deps[commit_repo: "repos.commit_repo"]

      def matching(text, limit:) = commit_repo.linkable(:commits, text:, limit:)

      def named(ids) = commit_repo.linkable(:commits, ids:)
    end
  end
end

# frozen_string_literal: true

module Record
  module Queries
    class RecentCommitRepos
      include Deps[commit_repo: "repos.commit_repo"]

      def call(now: Time.now) = commit_repo.recent_repos(now:)
    end
  end
end

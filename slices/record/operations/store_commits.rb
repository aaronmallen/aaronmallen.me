# frozen_string_literal: true

module Record
  module Operations
    class StoreCommits
      TIME_FORMAT = "%H:%M:%S"

      include Deps[commit_repo: "repos.commit_repo"]

      def call(repo, branches)
        seen = Set.new

        branches.sum { |branch| branch[:commits].count { seen.add?(it[:sha]) && added?(repo, branch[:name], it) } }
      end

      private

      def added?(repo, branch, commit)
        held = commit_repo.by_sha(commit[:sha])
        at = Blog::TimeZone.local(commit[:authored_at])

        commit_repo.import(
          branch:, repo:, sha: commit[:sha], message: commit[:message],
          additions: commit[:additions], deletions: commit[:deletions],
          commit_date: at.to_date, commit_time: at.strftime(TIME_FORMAT),
        )
        held.nil?
      end
    end
  end
end

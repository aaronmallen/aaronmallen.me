# frozen_string_literal: true

module Record
  module Operations
    class StoreCommits
      TIME_FORMAT = "%H:%M:%S"

      include Deps[commit_repo: "repos.commit_repo"]

      def call(repo, branches)
        commits = first_sightings(branches)
        known = commit_repo.known_shas(commits.keys)

        commits.each_value { |branch, commit| store(repo, branch, commit) }
        commits.keys.count { !known.include?(it) }
      end

      private

      def first_sightings(branches)
        branches.each_with_object({}) do |branch, found|
          branch[:commits].each { found[it[:sha]] ||= [branch[:name], it] }
        end
      end

      def store(repo, branch, commit)
        at = Blog::TimeZone.local(commit[:authored_at])

        commit_repo.import(
          branch:, repo:, sha: commit[:sha], message: commit[:message],
          additions: commit[:additions], deletions: commit[:deletions],
          commit_date: at.to_date, commit_time: at.strftime(TIME_FORMAT),
        )
      end
    end
  end
end

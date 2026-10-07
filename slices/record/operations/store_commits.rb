# frozen_string_literal: true

module Record
  module Operations
    class StoreCommits
      TIME_FORMAT = "%H:%M:%S"

      include Deps[commit_mutations: "repos.commit_mutations", commit_queries: "repos.commit_queries"]

      def call(repo, branches)
        commits = first_sightings(branches)
        known = commit_queries.known_shas(commits.keys)

        commits.each_value { |branch, commit| store(repo, branch, commit) }
        found = commits.except(*known)
        found.each_value { |_, commit| credit(repo, commit[:message]) }
        found.size
      end

      private

      def credit(repo, message)
        issues = CommitCredits.issues(message)
        agents = CommitCredits.agents(message)
        return if issues.empty? || agents.empty?

        Tasks::Jobs::CreditAgents.perform_async(repo, issues, agents)
      end

      def first_sightings(branches)
        branches.each_with_object({}) do |branch, found|
          branch[:commits].each { found[it[:sha]] ||= [branch[:name], it] }
        end
      end

      def store(repo, branch, commit)
        at = Blog::TimeZone.local(commit[:authored_at])

        commit_mutations.import(
          branch:, repo:, sha: commit[:sha], message: commit[:message],
          additions: commit[:additions], deletions: commit[:deletions],
          commit_date: at.to_date, commit_time: at.strftime(TIME_FORMAT),
        )
      end
    end
  end
end

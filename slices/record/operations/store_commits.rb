# frozen_string_literal: true

module Record
  module Operations
    class StoreCommits
      TIME_FORMAT = "%H:%M:%S"

      include Deps[
        commit_mutations: "repos.commit_mutations",
        commit_queries: "repos.commit_queries",
        parse_commit_credits: "operations.parse_commit_credits",
      ]

      def call(repo, branches)
        commits = first_sightings(branches)
        known = commit_queries.known_shas(commits.keys)

        rows = commits.except(*known).values.map { |branch, commit| row(repo, branch, commit) }
        stored = commit_mutations.import(rows)
        stored.each { credit(repo, commits.dig(it, 1, :message)) }
        stored.size
      end

      private

      def credit(repo, message)
        parse_commit_credits.call(message) => { agents:, issues: }
        return if issues.empty? || agents.empty?

        Tasks::Jobs::CreditAgents.perform_async(repo, issues, agents)
      end

      def first_sightings(branches)
        branches.each_with_object({}) do |branch, found|
          branch[:commits].each { found[it[:sha]] ||= [branch[:name], it] }
        end
      end

      def row(repo, branch, commit)
        at = Blog::TimeZone.local(commit[:authored_at])

        {
          branch:, repo:, sha: commit[:sha], message: commit[:message],
          additions: commit[:additions], deletions: commit[:deletions],
          commit_date: at.to_date, commit_time: at.strftime(TIME_FORMAT),
        }
      end
    end
  end
end

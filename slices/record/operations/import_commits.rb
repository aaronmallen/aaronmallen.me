# frozen_string_literal: true

module Record
  module Operations
    class ImportCommits < Blog::Operation
      include Record::Remote

      STALLED_AFTER = 2 * 60 * 60
      SYNC = Blog::Types::SyncName["commits"]

      include Deps[
        "github.client",
        commit_mutations: "repos.commit_mutations",
        commit_queries: "repos.commit_queries",
        sync_state_queries: "repos.sync_state_queries",
      ]

      def call(now: Time.now)
        pushed = step pushed_since_floor
        walks = commit_queries.walks
        started = (pushed | sync_state_queries.failed_repos(SYNC) | walks.keys) - going(walks, now)

        started.each { start(it, now) }
        started.size
      end

      private

      def going(walks, now) = walks.select { |_, held_at| held_at > now - STALLED_AFTER }.keys

      def pushed_since_floor
        remote(client) do
          Success(client.repositories(pushed_since: commit_queries.newest_commit_at&.-(PlanCommitWalk::OVERLAP)))
        end
      end

      def start(repo, now)
        commit_mutations.record_backfilled_to(repo, at: now)
        Jobs::BackfillRepoCommits.perform_async(repo, now.utc.iso8601)
      end
    end
  end
end

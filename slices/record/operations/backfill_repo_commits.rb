# frozen_string_literal: true

module Record
  module Operations
    class BackfillRepoCommits < Blog::Operation
      GROUNDED = :repository_start
      RESERVE = 1_000
      SYNC = Repos::SyncStateRepo::COMMITS

      include Deps[
        "github.client",
        commit_repo: "repos.commit_repo",
        store_commits: "operations.store_commits",
        sync_state_repo: "repos.sync_state_repo",
      ]

      def call(repo, clock:)
        step configured
        edge = step walking(repo)
        step affordable
        floor = commit_repo.synced_through(repo)
        branches = step read(repo, edge, floor)
        stored = store_commits.call(repo, branches)
        advance(repo, branches, edge:, floor:, clock:)

        stored
      end

      private

      def advance(repo, branches, edge:, floor:, clock:)
        sync_state_repo.clear_failure(SYNC, repo:)
        return finish(repo, clock) if CommitEdge.walked?(branches) || CommitEdge.floored?(branches, edge, floor)
        return ground(repo, clock, CommitEdge.unread(branches)) if CommitEdge.grounded?(branches, edge)

        commit_repo.record_backfilled_to(repo, at: CommitEdge.next_edge(branches, edge))
        Jobs::BackfillRepoCommits.perform_async(repo, clock.utc.iso8601)
      end

      def affordable
        remaining = client.rate_limit_remaining

        remaining.nil? || remaining > RESERVE ? Success(remaining) : Failure(:rate_limited)
      end

      def configured = client.configured? ? Success() : Failure(:not_configured)

      def finish(repo, clock) = commit_repo.finish_walk(repo, synced_through: clock - CommitEdge::OVERLAP)

      def ground(repo, clock, unread)
        sync_state_repo.record_failure(SYNC, GROUNDED, message: "#{unread.join(', ')} still unread", repo:)
        finish(repo, clock)
      end

      def read(repo, edge, floor)
        default, rest = client.commits(repo, since: floor, before: edge).items.partition { it[:default] }

        Success(default + rest)
      rescue Record::GitHub::Client::RateLimited
        Failure(:rate_limited)
      rescue Record::GitHub::Client::Error => e
        stop(repo, :github_failed, e.message)
      end

      def stop(repo, reason, message)
        sync_state_repo.record_failure(SYNC, reason, message:, repo:)
        commit_repo.end_walk(repo)
        Failure(reason)
      end

      def walking(repo)
        edge = commit_repo.backfilled_to(repo)
        return Failure(:not_walking) unless edge

        commit_repo.hold_walk(repo)
        Success(edge)
      end
    end
  end
end

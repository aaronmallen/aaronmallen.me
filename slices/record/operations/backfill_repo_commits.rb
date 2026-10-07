# frozen_string_literal: true

module Record
  module Operations
    class BackfillRepoCommits < Operation
      GROUNDED = :repository_start
      RESERVE = 1_000
      SYNC = Blog::Types::SyncName["commits"]

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
        return sweep(repo, edge, clock) if floor && edge <= floor

        branches = step read(repo, edge, floor)
        stored = store_commits.call(repo, branches)

        stored + advance(repo, branches, edge:, floor:, clock:)
      end

      private

      def advance(repo, branches, edge:, floor:, clock:)
        sync_state_repo.clear_failure(SYNC, repo:)
        return below(repo, floor, clock) if CommitEdge.walked?(branches) || CommitEdge.floored?(branches, edge, floor)
        return ground(repo, clock, CommitEdge.unread(branches)) if CommitEdge.grounded?(branches, edge)

        queue(repo, CommitEdge.next_edge(branches, edge), clock)
      end

      def affordable
        remaining = client.rate_limit_remaining

        remaining.nil? || remaining > RESERVE ? Success(remaining) : Failure(:rate_limited)
      end

      def below(repo, floor, clock)
        return finish(repo, clock) unless floor

        commit_repo.record_backfilled_to(repo, at: floor)
        step affordable
        sweep(repo, floor, clock)
      end

      def configured = client.configured? ? Success() : Failure(:not_configured)

      def finish(repo, clock)
        commit_repo.finish_walk(repo, synced_through: clock - CommitEdge::OVERLAP)
        0
      end

      def ground(repo, clock, unread)
        sync_state_repo.record_failure(SYNC, GROUNDED, message: "#{unread.join(', ')} still unread", repo:)
        finish(repo, clock)
      end

      def known(branches) = commit_repo.known_shas(branches.flat_map { |branch| branch[:commits].map { it[:sha] } })

      def queue(repo, edge, clock)
        commit_repo.record_backfilled_to(repo, at: edge)
        Jobs::BackfillRepoCommits.perform_async(repo, clock.utc.iso8601)
        0
      end

      def read(repo, edge, floor)
        default, rest = client.commits(repo, since: floor, before: edge).items.partition { it[:default] }

        Success(default + rest)
      rescue Record::GitHub::Client::RateLimited
        Failure(:rate_limited)
      rescue Record::GitHub::Client::Error => e
        stop(repo, :github_failed, e.message)
      end

      def settled?(branch, seen)
        branch[:complete] || branch[:commits].empty? || branch[:commits].any? { seen.include?(it[:sha]) }
      end

      def stop(repo, reason, message)
        sync_state_repo.record_failure(SYNC, reason, message:, repo:)
        commit_repo.end_walk(repo)
        Failure(reason)
      end

      def sweep(repo, edge, clock)
        branches = step read(repo, edge, nil)
        seen = known(branches)
        stored = store_commits.call(repo, branches)
        open = branches.reject { settled?(it, seen) }

        stored + (open.empty? ? finish(repo, clock) : queue(repo, CommitEdge.next_edge(open, edge), clock))
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

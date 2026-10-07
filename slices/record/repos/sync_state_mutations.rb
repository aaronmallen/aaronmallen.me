# frozen_string_literal: true

module Record
  module Repos
    class SyncStateMutations < DB::Repo
      FAILURE = SyncStateQueries::FAILURE

      def clear_failure(sync, repo: nil) = failure_row(sync, repo).delete

      def reap_failures(sync, keep:)
        failures = sync_states.of_kind(FAILURE).for_sync(sync)
        gone = failures.per_repo.pluck(:repo) - keep
        return 0 if gone.empty?

        failures.for_repos(gone).delete
      end

      def record_failure(sync, reason, at: Time.now, message: nil, repo: nil)
        prior = failure_row(sync, repo).one

        sync_states.record(
          kind: FAILURE, sync:, repo:,
          failing_since: prior&.failing_since || at,
          failure_count: prior ? prior.failure_count + 1 : 1,
          failure_message: message&.to_s,
          failure_reason: reason.to_s,
          synced_at: at,
        )
        reason
      end

      private

      def failure_row(sync, repo) = sync_states.of(FAILURE, sync:, repo:)
    end
  end
end

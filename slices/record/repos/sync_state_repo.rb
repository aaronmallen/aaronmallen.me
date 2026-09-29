# frozen_string_literal: true

module Record
  module Repos
    class SyncStateRepo < Blog::DB::Repo
      ANALYTICS_ROLLUP = "analytics_rollup"
      COMMITS = "commits"
      COUNTRY_DATABASE = "country_database"
      FAILURE = "failure"
      ISSUES = "issues"
      PAGE_LIMIT = "page_limit"
      PROJECTS = "projects"

      def clear_failure(sync, repo: nil) = failure_row(sync, repo).delete

      def failed_repos(sync) = failure_rows.for_sync(sync).per_repo.pluck(:repo)

      def failure(sync, repo: nil) = to_failure(failure_row(sync, repo).one)

      def failures = listed(failure_rows.exclude(sync: COMMITS, failure_reason: PAGE_LIMIT))

      def reap_failures(sync, keep:)
        gone = failed_repos(sync) - keep
        return 0 if gone.empty?

        failure_rows.for_sync(sync).for_repos(gone).delete
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

      def failure_rows = sync_states.of_kind(FAILURE)

      def listed(rows) = rows.in_sync_order.to_a.map { to_failure(it) }

      def to_failure(state)
        return unless state

        {
          at: state.synced_at, count: state.failure_count, message: state.failure_message,
          reason: state.failure_reason, repo: state.repo, since: state.failing_since, sync: state.sync,
        }
      end
    end
  end
end

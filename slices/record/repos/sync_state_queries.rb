# frozen_string_literal: true

module Record
  module Repos
    class SyncStateQueries < Blog::DB::Repo
      COMMITS = Blog::Types::SyncName["commits"]
      FAILURE = Blog::Types::SyncStateKind["failure"]
      PAGE_LIMIT = "page_limit"

      def failed_repos(sync) = failure_rows.for_sync(sync).per_repo.pluck(:repo)

      def failure(sync, repo: nil) = to_failure(sync_states.of(FAILURE, sync:, repo:).one)

      def failures = listed(failure_rows.exclude(sync: COMMITS, failure_reason: PAGE_LIMIT))

      private

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

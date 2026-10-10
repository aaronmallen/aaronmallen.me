# frozen_string_literal: true

module Record
  module Repos
    class CommitMutations < Blog::DB::Repo
      BACKFILL_KIND = CommitQueries::BACKFILL_KIND
      IMPORT_LOCK = "commit import"
      SYNC_KIND = CommitQueries::SYNC_KIND

      def end_walk(repo) = sync_states.of(BACKFILL_KIND, repo:).delete

      def finish_walk(repo, synced_through:)
        transaction do
          record_synced_through(repo, at: synced_through)
          end_walk(repo)
        end
      end

      def hold_walk(repo) = sync_states.of(BACKFILL_KIND, repo:).update(updated_at: Time.now)

      def import(**attrs) = commits.command(:import).call(attrs)

      def reap_walks(keep:)
        walks = sync_states.of_kind(BACKFILL_KIND)
        gone = walks.pluck(:repo) - keep
        return 0 if gone.empty?

        walks.for_repos(gone).delete
      end

      def record_backfilled_to(repo, at:) = record_state(BACKFILL_KIND, at, repo:)

      def record_synced_through(repo, at:) = record_state(SYNC_KIND, at, repo:)

      def with_import_lock(&) = sync_states.with_advisory_lock(IMPORT_LOCK, &)

      private

      def record_state(kind, at, repo:)
        sync_states.record(kind:, repo:, synced_at: at)
        at
      end
    end
  end
end

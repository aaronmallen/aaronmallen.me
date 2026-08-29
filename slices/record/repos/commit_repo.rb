# frozen_string_literal: true

module Record
  module Repos
    class CommitRepo < Blog::DB::Repo
      include Dry::Monads[:result]

      BACKFILL_KIND = "backfill"
      IMPORT_LOCK = 303_303
      NONE = Dry::Core::Constants::EMPTY_ARRAY
      REPO_DAYS = 30
      SYNC_KIND = "commits"

      def backfilled_to(repo) = state_at(BACKFILL_KIND, repo)

      def between(from:, to:, repos: NONE, limit: nil)
        found = commits.between(from, to)
        found = found.in_repos(repos) unless repos.empty?
        found = found.newest_first

        (limit ? found.limit(limit) : found).to_a
      end

      def by_id(id) = commits.by_pk(id).one

      def by_sha(sha) = commits.with_sha(sha).one

      def end_walk(repo) = sync_states.of(BACKFILL_KIND, repo:).delete

      def finish_walk(repo, synced_through:)
        transaction do
          record_synced_through(repo, at: synced_through)
          end_walk(repo)
        end
      end

      def hold_walk(repo) = sync_states.of(BACKFILL_KIND, repo:).update(updated_at: Time.now)

      def import(**attrs) = commits.command(:import).call(attrs)

      def last_synced_at = sync_states.of_kind(SYNC_KIND).max(:updated_at)

      def newest_commit_at = commits.max(:created_at)

      def reap_walks(keep:)
        gone = walks.keys - keep
        return 0 if gone.empty?

        sync_states.of_kind(BACKFILL_KIND).for_repos(gone).delete
      end

      def recent_repos(now: Time.now)
        today = Blog::TimeZone.today(now)

        commits.between(today - (REPO_DAYS - 1), today).repo_names
      end

      def record_backfilled_to(repo, at:) = record_state(BACKFILL_KIND, at, repo:)

      def record_synced_through(repo, at:) = record_state(SYNC_KIND, at, repo:)

      def synced_through(repo) = state_at(SYNC_KIND, repo)

      def today(now: Time.now) = commits.on(Blog::TimeZone.today(now)).newest_first.to_a

      def today_totals(now: Time.now) = commits.on(Blog::TimeZone.today(now)).line_totals.one.to_h

      def walks = sync_states.of_kind(BACKFILL_KIND).to_a.to_h { [it.repo, it.updated_at] }

      def with_import_lock(&) = sync_states.with_advisory_lock(IMPORT_LOCK, busy: Failure(:lock_busy), &)

      private

      def record_state(kind, at, repo:)
        sync_states.record(kind:, repo:, synced_at: at)
        at
      end

      def state_at(kind, repo) = sync_states.of(kind, repo:).one&.synced_at
    end
  end
end

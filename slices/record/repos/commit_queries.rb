# frozen_string_literal: true

module Record
  module Repos
    class CommitQueries < DB::Repo
      BACKFILL_KIND = Blog::Types::SyncStateKind["backfill"]
      NONE = Blog::Constants::EMPTY_ARRAY
      SYNC_KIND = Blog::Types::SyncStateKind["commits"]

      def backfilled_to(repo) = state_at(BACKFILL_KIND, repo)

      def between(from:, to:, repos: NONE, limit: nil)
        found = commits.between(from, to)
        found = found.in_repos(repos) unless repos.empty?
        found = found.newest_first

        (limit ? found.limit(limit) : found).to_a
      end

      def by_id(id) = commits.by_pk(id).one

      def known_shas(shas) = shas.empty? ? Set.new : commits.with_sha(shas).pluck(:sha).to_set

      def last_synced_at = sync_states.of_kind(SYNC_KIND).max(:updated_at)

      def newest_commit_at = commits.max(:created_at)

      def synced_through(repo) = state_at(SYNC_KIND, repo)

      def today(now: Time.now, limit: nil)
        found = commits.on(Blog::TimeZone.today(now)).newest_first

        (limit ? found.limit(limit) : found).to_a
      end

      def today_repos(now: Time.now) = commits.on(Blog::TimeZone.today(now)).repo_names

      def today_totals(now: Time.now) = commits.on(Blog::TimeZone.today(now)).day_totals.one.to_h

      def walks = sync_states.of_kind(BACKFILL_KIND).to_a.to_h { [it.repo, it.updated_at] }

      private

      def state_at(kind, repo) = sync_states.of(kind, repo:).one&.synced_at
    end
  end
end

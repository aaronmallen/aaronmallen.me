# frozen_string_literal: true

module Record
  module Repos
    class PullRequestMutations < Blog::DB::Repo
      IMPORT_LOCK = "pull request import"
      SYNC_KIND = PullRequestQueries::SYNC_KIND

      def import(found, synced_through:)
        transaction do
          pull_requests.command(:import).call(latest(found)) unless found.empty?
          sync_states.record(kind: SYNC_KIND, synced_at: synced_through)
        end
      end

      def with_import_lock(&) = pull_requests.with_advisory_lock(IMPORT_LOCK, &)

      private

      def latest(found) = found.to_h { [it.values_at(:repo, :number), it] }.values
    end
  end
end

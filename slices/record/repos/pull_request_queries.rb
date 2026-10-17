# frozen_string_literal: true

module Record
  module Repos
    class PullRequestQueries < Blog::DB::Repo
      SYNC_KIND = Blog::Types::SyncStateKind["pull_requests"]

      def between(from:, to:, limit: nil)
        found = pull_requests.between(from, to).newest_first

        found.limit(limit).to_a
      end

      def by_id(id) = pull_requests.by_pk(id).one

      def synced_through = sync_states.of(SYNC_KIND).one&.synced_at
    end
  end
end

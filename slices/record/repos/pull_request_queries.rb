# frozen_string_literal: true

module Record
  module Repos
    class PullRequestQueries < DB::Repo
      def between(from:, to:, limit: nil)
        found = pull_requests.between(from, to).newest_first

        (limit ? found.limit(limit) : found).to_a
      end

      def by_id(id) = pull_requests.by_pk(id).one

      def newest_import_at = pull_requests.max(:updated_at)
    end
  end
end

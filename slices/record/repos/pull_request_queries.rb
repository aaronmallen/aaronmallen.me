# frozen_string_literal: true

module Record
  module Repos
    class PullRequestQueries < DB::Repo
      def by_id(id) = pull_requests.by_pk(id).one

      def newest_import_at = pull_requests.max(:updated_at)
    end
  end
end

# frozen_string_literal: true

module API
  module Repos
    class ActivityViewQueries < Blog::DB::Repo
      POST = Blog::Types::ActivityKind["post"]

      include Deps[rollup_queries: "analytics.repos.analytics_rollup_queries"]

      def views(rows) = rows.any? { it.type == POST } ? rollup_queries.views_by_path : Blog::Constants::EMPTY_HASH
    end
  end
end

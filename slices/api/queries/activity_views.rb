# frozen_string_literal: true

module API
  module Queries
    class ActivityViews
      POST = Blog::Types::ActivityKind["post"]

      include Deps[rollup_queries: "analytics.repos.analytics_rollup_queries"]

      def call(rows) = rows.any? { it.type == POST } ? rollup_queries.views_by_path : Blog::Constants::EMPTY_HASH
    end
  end
end

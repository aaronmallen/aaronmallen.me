# frozen_string_literal: true

module Analytics
  module Queries
    class TopPaths
      include Deps[rollup_repo: "repos.analytics_rollup_repo"]

      def call(from:, to:) = rollup_repo.top_paths(from:, to:)
    end
  end
end

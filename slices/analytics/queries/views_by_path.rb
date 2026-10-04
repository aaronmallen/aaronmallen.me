# frozen_string_literal: true

module Analytics
  module Queries
    class ViewsByPath
      include Deps[rollup_repo: "repos.analytics_rollup_repo", unrolled_summaries: "queries.unrolled_summaries"]

      def call(to: Blog::TimeZone.today)
        from = to - (Repos::AnalyticsRollupRepo::VIEW_DAYS - 1)
        found = rollup_repo.views_by_path(from:, to:)

        unrolled_summaries.call(from:, to:).flat_map(&:paths).each do |row|
          found[row.path] = found.fetch(row.path, 0) + row.views
        end
        found
      end
    end
  end
end

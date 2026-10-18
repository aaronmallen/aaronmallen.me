# frozen_string_literal: true

module Performance
  module Repos
    class RollupQueries < Blog::DB::Repo
      def newest_day = performance_rollups.dataset.max(:day)

      def oldest_day
        tables = [performance_jobs, performance_pages, performance_requests]
        occurred_at = tables.filter_map { it.dataset.min(:occurred_at) }.min

        Blog::TimeZone.local_date(occurred_at) if occurred_at
      end
    end
  end
end

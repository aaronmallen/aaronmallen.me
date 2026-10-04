# frozen_string_literal: true

module Analytics
  module Queries
    class ViewsByPost
      UNSEEN = { views: 0, visitors: 0, read_throughs: 0 }.freeze

      include Deps[rollup_repo: "repos.analytics_rollup_repo", unrolled_summaries: "queries.unrolled_summaries"]

      def call(post_ids, to: Blog::TimeZone.today)
        from = to - (Repos::AnalyticsRollupRepo::VIEW_DAYS - 1)
        found = rollup_repo.views_by_post(post_ids, from:, to:)
        posts = rollup_repo.post_paths(post_ids)

        unrolled_summaries.call(from:, to:).each { add(found, posts, it) }
        found
      end

      private

      def add(found, posts, summary)
        summary.paths.each do |row|
          id = posts[row.path]
          next unless id

          seen = { views: row.views, visitors: row.visitors, read_throughs: summary.read_throughs.fetch(row.path, 0) }
          found[id] = found.fetch(id, UNSEEN).merge(seen) { |_key, held, more| held + more }
        end
      end
    end
  end
end

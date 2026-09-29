# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupPaths < Blog::DB::Relation
      FIGURES = proc do
        [
          integer.sum(views).as(:views),
          integer.sum(visitors).as(:visitors),
          integer.sum(read_seconds).as(:read_seconds),
          integer.sum(bounces).as(:bounces),
        ]
      end
      NEWEST_FIRST = Sequel.desc(:day)
      POST_ID = Sequel[:posts][:id]
      POST_PATH = Sequel.join(["#{Blog::Site::WRITING}/", Sequel[:posts][:slug]])
      RECENT_TITLE = proc { string.array_agg(title).order(NEWEST_FIRST).filter(TITLED).sql_subscript(1).as(:title) }
      TITLED = Sequel.~(title: nil)

      schema :analytics_rollup_paths, infer: true

      def between(from, to) = where(day: from..to)

      def on(day) = where(day:)

      def top_by_views
        figures = unordered.select(:path, &RECENT_TITLE).select_append(&FIGURES).group(:path)

        figures.order { [sum(views).desc, path.asc] }
      end

      def views_by_path = unordered.select(:path) { integer.sum(views).as(:views) }.group(:path)

      def views_by_post(post_ids)
        joined = unordered.join(:posts, self[:path].is(POST_PATH)).where(POST_ID => post_ids)

        joined.select { [integer(POST_ID).as(:post_id), integer.sum(views).as(:views)] }.group(POST_ID)
      end
    end
  end
end

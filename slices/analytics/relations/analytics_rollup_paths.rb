# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupPaths < Blog::DB::Relation
      use :daily_rollup

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
      POST_FIGURES = proc do
        [
          integer(POST_ID).as(:post_id),
          integer.sum(views).as(:views),
          integer.sum(visitors).as(:visitors),
          integer.coalesce(integer.sum(read_throughs), 0).as(:read_throughs),
        ]
      end
      POST_PATH = Sequel.join(["#{Blog::Site::WRITING}/", Sequel[:posts][:slug]])
      PUBLISH_DAY = site_day(Sequel[:posts][:published_at])
      PUBLISHED = Blog::Types::PostStatus["published"]
      RECENT_TITLE = proc { string.array_agg(title).order(NEWEST_FIRST).filter(TITLED).sql_subscript(1).as(:title) }
      ROLLED = Sequel[:analytics_rollup_paths]
      TITLED = Sequel.~(title: nil)

      schema :analytics_rollup_paths, infer: true

      def first_days(span)
        day = ROLLED[:day]
        within = Sequel.&({ ROLLED[:path] => POST_PATH }, day >= PUBLISH_DAY, day < PUBLISH_DAY + span)
        posts = dataset.db[:posts].where(Sequel[:posts][:status] => PUBLISHED)

        joined = posts.left_join(:analytics_rollup_paths, within)

        joined.select(POST_PATH.as(:path), PUBLISH_DAY.as(:published_on), day, ROLLED[:visitors])
      end

      def post_paths(post_ids)
        dataset.db[:posts].where(POST_ID => post_ids).select(POST_ID.as(:post_id), POST_PATH.as(:path))
      end

      def read_throughs_by_path
        known = unordered.exclude(read_throughs: nil)

        known.select(:path) { integer.sum(read_throughs).as(:read_throughs) }.group(:path)
      end

      def top_by_views
        figures = unordered.select(:path, &RECENT_TITLE).select_append(&FIGURES).group(:path)

        figures.order { [sum(views).desc, path.asc] }
      end

      def views_by_path = unordered.select(:path) { integer.sum(views).as(:views) }.group(:path)

      def views_by_post(post_ids)
        joined = unordered.join(:posts, self[:path].is(POST_PATH)).where(POST_ID => post_ids)

        joined.select(&POST_FIGURES).group(POST_ID)
      end
    end
  end
end

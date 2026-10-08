# frozen_string_literal: true

module Analytics
  module Repos
    class AnalyticsRollupQueries < DB::Repo
      KEYS = { countries: :country_code, paths: :path, referrers: :host }.freeze
      RANKS = { countries: :visitors, paths: :views, referrers: :visitors }.freeze
      SUMS = {
        countries: %i[views visitors].freeze,
        paths: %i[views visitors read_seconds bounces].freeze,
        referrers: %i[views visitors].freeze,
      }.freeze
      TOP_ROWS = 100
      TOTALS = %i[views visitors read_seconds].freeze
      UNSEEN = { views: 0, visitors: 0, read_throughs: 0 }.freeze
      VIEW_DAYS = 90
      ZERO_DAY = { views: 0, visitors: 0 }.freeze

      include Deps[event_queries: "repos.analytics_event_queries"]

      def by_day(day) = analytics_rollups.by_pk(day).one

      def days(from:, to:) = analytics_rollups.between(from, to).oldest_first.to_a

      def newest_day = analytics_rollups.newest_day

      def post_ids_by_path(paths)
        analytics_rollup_paths.posts_at(paths).to_a.to_h { [it.fetch(:path), it.fetch(:post_id)] }
      end

      def reach_between(from:, to:, path: nil)
        complete = event_queries.complete_from
        counts = months(from, to).map { reach(it, path, complete) }

        counts.sum unless counts.include?(nil)
      end

      def read_throughs_between(from:, to:)
        counts = by_path(paths_between(from, to).read_throughs_by_path, :read_throughs)
        unrolled_summaries(from:, to:).each { counts.merge!(it.read_throughs) { |_path, held, more| held + more } }

        counts.reject { |_path, count| count.zero? }
      end

      def summary_between(from:, to:)
        live = unrolled_summaries(from:, to:)

        {
          countries: ranked(:countries, analytics_rollup_countries.between(from, to).top_by_visitors.to_a, live),
          days: summary_days(from, to, live),
          **summary_tops(from, to, live),
          totals: summary_totals(from, to, live),
        }
      end

      def totals(from:, to:) = analytics_rollups.between(from, to).totals.one

      def unrolled_summaries(from:, to:)
        oldest = event_queries.oldest_day
        return Blog::Constants::EMPTY_ARRAY unless oldest

        days = [from, oldest].max..[to, Blog::TimeZone.today].min
        rolled = days(from: days.first, to: days.last).map(&:day)

        days.reject { rolled.include?(it) }.map { event_queries.summary_for(it) }
      end

      def views_by_path(to: Blog::TimeZone.today)
        from = to - (VIEW_DAYS - 1)
        found = by_path(paths_between(from, to).views_by_path, :views)

        unrolled_summaries(from:, to:).flat_map(&:paths).each { found[it.path] = found.fetch(it.path, 0) + it.views }
        found
      end

      def views_by_post(post_ids, to: Blog::TimeZone.today)
        from = to - (VIEW_DAYS - 1)
        found = paths_between(from, to).views_by_post(post_ids).to_a.to_h { [it.post_id, it.to_h.slice(*UNSEEN.keys)] }

        posts = post_paths(post_ids)

        unrolled_summaries(from:, to:).each { add_views(found, posts, it) }
        found
      end

      private

      def add_views(found, posts, summary)
        summary.paths.each do |row|
          id = posts[row.path]
          next unless id

          seen = { views: row.views, visitors: row.visitors, read_throughs: summary.read_throughs.fetch(row.path, 0) }
          found[id] = found.fetch(id, UNSEEN).merge(seen) { |_key, held, more| held + more }
        end
      end

      def by_path(rows, field) = rows.to_a.to_h { [it.path, it.public_send(field)] }

      def combine(rows, key, fields)
        rows.each_with_object({}) do |row, found|
          held = found[row[key]]
          found[row[key]] = held ? held.merge(row, fields.to_h { [it, sum(held[it], row[it])] }) : row
        end.values
      end

      def months(from, to) = (from..to).slice_when { |day, after| day.month != after.month }.map { it.first..it.last }

      def paths_between(from, to) = analytics_rollup_paths.between(from, to)

      def post_paths(post_ids)
        analytics_rollup_paths.post_paths(post_ids).to_a.to_h { [it.fetch(:path), it.fetch(:post_id)] }
      end

      def ranked(name, rolled, live)
        key = KEYS.fetch(name)
        rank = RANKS.fetch(name)
        so_far = live.flat_map { it.public_send(name) }

        combine((rolled + so_far).map(&:to_h), key, SUMS.fetch(name)).sort_by { standing(it, rank, key) }
      end

      def reach(days, path, complete)
        return event_queries.live_reach(from: days.first, to: days.last, path:) if days.first >= complete
        return unless whole_month?(days)

        rolled = by_path(analytics_rollup_reach.in_month(days.first), :reach)
        rolled.fetch(path, 0) unless rolled.empty?
      end

      def standing(row, rank, key) = [row[rank] ? 0 : 1, -row[rank].to_i, -row[:views], row[key].to_s]

      def sum(held, found) = held && found ? held + found : held || found

      def summary_days(from, to, live)
        found = days(from:, to:).to_h { [it.day, { views: it.views, visitors: it.visitors }] }
        live.each { found[it.day] = it.totals.to_h.slice(*ZERO_DAY.keys) }

        (from..to).map { { day: it, **found.fetch(it, ZERO_DAY) } }
      end

      def summary_tops(from, to, live)
        {
          paths: ranked(:paths, top(paths_between(from, to).top_by_views), live),
          referrers: ranked(:referrers, top(analytics_rollup_referrers.between(from, to).top_by_visitors), live),
        }.transform_values { it.take(TOP_ROWS) }
      end

      def summary_totals(from, to, live)
        found = totals(from:, to:).to_h

        TOTALS.to_h { |key| [key, live.sum(found.fetch(key)) { it.totals.public_send(key) }] }
      end

      def top(rows) = rows.limit(TOP_ROWS).to_a

      def whole_month?(days) = days.first.mday == 1 && days.last.next_day.mday == 1
    end
  end
end

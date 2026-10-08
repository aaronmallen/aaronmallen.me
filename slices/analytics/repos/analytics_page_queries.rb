# frozen_string_literal: true

module Analytics
  module Repos
    class AnalyticsPageQueries < DB::Repo
      FIGURES = %i[views visitors read_seconds].freeze
      COUNTED = [*FIGURES, :bounces].freeze
      FIRST_DAYS = 30
      LINK = %i[link_host link_path].freeze
      NAMED = { countries: :country_name }.freeze
      RANKED = { countries: :country_code, referrers: :host }.freeze
      ZERO_DAY = COUNTED.to_h { [it, 0] }.freeze

      include Deps[
        event_queries: "repos.analytics_event_queries",
        rank_rows: "operations.rank_rows",
        rollup_queries: "repos.analytics_rollup_queries",
      ]

      def clicks_between(path:, from:, to:)
        rolled = analytics_rollup_clicks.between(from, to).for_path(path).top_by_clicks.to_a.map(&:to_h)
        rows = rolled + live_rows(:clicks, path, from:, to:)

        combined_clicks(rows).sort_by { [-it.fetch(:clicks), *it.values_at(*LINK)] }
      end

      def devices_between(from:, to:, path: nil)
        rolled = analytics_rollup_devices.between(from, to).for_path(path).top_by_visitors.to_a.map(&:to_h)

        rank_rows.call(rolled + live_rows(:devices, path, from:, to:), key: :device_class)
      end

      def first_days(path, today: Blog::TimeZone.today)
        rows = analytics_rollup_paths.first_days(FIRST_DAYS).to_a
        curves = curves(rows, today)
        measured = curves.slice(*measured_paths(rows, today))

        { span: FIRST_DAYS, days: curves.fetch(path, Blog::Constants::EMPTY_ARRAY), median: medians(measured.values) }
      end

      def page_between(path:, from:, to:)
        window = { path:, from:, to: }
        live = rollup_queries.unrolled_summaries(from:, to:)
        days = page_days(window, live)

        {
          bounces: days.sum { it.fetch(:bounces) },
          days: days.map { it.except(:bounces) },
          totals: FIGURES.to_h { |key| [key, days.sum { it.fetch(key) }] },
          **RANKED.to_h { |name, key| [name, page_ranked(name, key, window, live)] },
        }
      end

      def scroll_depths_between(from:, to:, path: nil)
        rolled = analytics_rollup_scroll_depths.between(from, to)
        rolled = rolled.for_path(path) if path
        live = path ? live_rows(:scroll_depths, path, from:, to:) : all_live_rows(:scroll_depths, from:, to:)
        rows = rolled.by_depth.to_a.map(&:to_h) + live
        views = rows.sum { it.fetch(:views) }

        { views:, reached: Blog::Types::ScrollDepth.values.select(&:positive?).map { reached(it, rows, views) } }
      end

      def sources_between(from:, to:, path: nil)
        rolled = analytics_rollup_sources.between(from, to).for_path(path).top_by_visitors.to_a.map(&:to_h)

        rank_rows.call(rolled + live_rows(:sources, path, from:, to:), key: :source)
      end

      private

      def all_live_rows(name, from:, to:) = rollup_queries.unrolled_summaries(from:, to:).flat_map(&name)

      def combined_clicks(rows)
        rows.group_by { it.values_at(*LINK) }.map do |(link_host, link_path), found|
          { link_host:, link_path:, clicks: found.sum { it.fetch(:clicks) } }
        end
      end

      def curves(rows, today)
        visitors = first_day_visitors(rows, today)

        rows.to_h { [it.fetch(:path), it.fetch(:published_on)] }.to_h do |path, first|
          [path, (first..[first + FIRST_DAYS - 1, today].min).map { visitors.fetch([path, it], 0) }]
        end
      end

      def figures(row) = row.to_h.slice(*COUNTED)

      def first_day_live(today)
        rollup_queries.unrolled_summaries(from: today - (FIRST_DAYS - 1), to: today).flat_map do |summary|
          summary.paths.map { [[it.path, summary.day], it.visitors] }
        end
      end

      def first_day_visitors(rows, today)
        rolled = rows.select { it[:day] }.to_h { [[it.fetch(:path), it.fetch(:day)], it.fetch(:visitors)] }

        rolled.merge(first_day_live(today).to_h)
      end

      def live_day(summary, path)
        row = summary.paths.find { it.path == path }
        row ? figures(row) : ZERO_DAY
      end

      def live_rows(name, path, from:, to:) = all_live_rows(name, from:, to:).select { it.fetch(:path) == path }

      def measured_paths(rows, today)
        first = [analytics_rollups.oldest_day, event_queries.oldest_day].compact.min || today

        rows.select { it.fetch(:published_on) >= first }.map { it.fetch(:path) }
      end

      def medians(curves)
        (0...curves.map(&:size).max.to_i).map { |index| middle(curves.filter_map { it[index] }.sort) }
      end

      def middle(counts)
        half = counts.size / 2

        counts.size.odd? ? counts[half] : (counts[half - 1] + counts[half]).fdiv(2)
      end

      def page_days(window, live)
        found = page_rows(analytics_rollup_paths, window).to_a.to_h { [it.day, figures(it)] }
        live.each { found[it.day] = live_day(it, window.fetch(:path)) }

        (window.fetch(:from)..window.fetch(:to)).map { { day: it, **found.fetch(it, ZERO_DAY) } }
      end

      def page_ranked(name, key, window, live)
        rolled = page_rows(public_send(:"analytics_rollup_page_#{name}"), window).top_by_visitors.to_a.map(&:to_h)
        rows = rolled + live.flat_map { it.public_send(:"page_#{name}") }.select { it.fetch(:path) == window[:path] }

        rank_rows.call(rows, key:, named: NAMED[name])
      end

      def page_rows(relation, window) = relation.between(window[:from], window[:to]).for_path(window[:path])

      def reached(depth, rows, views)
        count = rows.select { it.fetch(:scroll_depth) >= depth }.sum { it.fetch(:views) }

        { depth:, views: count, share: views.zero? ? nil : (count.to_f / views).round(3) }
      end
    end
  end
end

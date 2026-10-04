# frozen_string_literal: true

module Analytics
  module Queries
    class FirstDays
      SPAN = 30

      include Deps[
        event_repo: "repos.analytics_event_repo",
        rollup_repo: "repos.analytics_rollup_repo",
        unrolled_summaries: "queries.unrolled_summaries",
      ]

      def call(path, today: Blog::TimeZone.today)
        rows = rollup_repo.first_days(SPAN)
        curves = curves(rows, today)
        measured = curves.slice(*measured_paths(rows, today))

        { span: SPAN, days: curves.fetch(path, Blog::Constants::EMPTY_ARRAY), median: medians(measured.values) }
      end

      private

      def curves(rows, today)
        visitors = visitors(rows, today)

        rows.to_h { [it.fetch(:path), it.fetch(:published_on)] }.to_h do |path, first|
          [path, (first..[first + SPAN - 1, today].min).map { visitors.fetch([path, it], 0) }]
        end
      end

      def live(today)
        unrolled_summaries.call(from: today - (SPAN - 1), to: today).flat_map do |summary|
          summary.paths.map { [[it.path, summary.day], it.visitors] }
        end
      end

      def measured_paths(rows, today)
        first = [rollup_repo.oldest_day, event_repo.oldest_day].compact.min || today

        rows.select { it.fetch(:published_on) >= first }.map { it.fetch(:path) }
      end

      def medians(curves)
        (0...curves.map(&:size).max.to_i).map { |index| middle(curves.filter_map { it[index] }.sort) }
      end

      def middle(counts)
        half = counts.size / 2

        counts.size.odd? ? counts[half] : (counts[half - 1] + counts[half]).fdiv(2)
      end

      def visitors(rows, today)
        rolled = rows.select { it[:day] }.to_h { [[it.fetch(:path), it.fetch(:day)], it.fetch(:visitors)] }

        rolled.merge(live(today).to_h)
      end
    end
  end
end

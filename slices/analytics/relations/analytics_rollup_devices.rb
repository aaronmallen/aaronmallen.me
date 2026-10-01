# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupDevices < Blog::DB::Relation
      FIGURES = proc { [integer.sum(views).as(:views), integer.sum(visitors).as(:visitors)] }

      schema :analytics_rollup_devices, infer: true

      def between(from, to) = where(day: from..to)

      def for_path(path) = where(path:)

      def on(day) = where(day:)

      def top_by_visitors
        counts = unordered.select(:device_class, &FIGURES).group(:device_class)

        counts.order { [sum(visitors).desc, sum(views).desc, device_class.asc] }
      end
    end
  end
end

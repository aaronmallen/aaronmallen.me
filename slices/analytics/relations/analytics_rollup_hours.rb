# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupHours < Blog::DB::Relation
      WEEKDAY = Sequel.extract(:isodow, :day).cast(Integer)

      use :daily_rollup

      schema :analytics_rollup_hours, infer: true

      def visitors_by_weekday_hour
        found = unordered.dataset.select(WEEKDAY.as(:weekday), :hour, Sequel.function(:sum, :visitors).as(:visitors))

        found.group(WEEKDAY, :hour).to_h { [it.values_at(:weekday, :hour), it.fetch(:visitors)] }
      end
    end
  end
end

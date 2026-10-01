# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupReach < Blog::DB::Relation
      schema :analytics_rollup_reach, infer: true

      def in_month(month) = where(month:)
    end
  end
end

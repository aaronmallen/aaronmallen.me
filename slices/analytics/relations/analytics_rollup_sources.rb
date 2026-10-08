# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupSources < Blog::DB::Relation
      use :daily_rollup

      schema :analytics_rollup_sources, infer: true

      ranks_by :source
    end
  end
end

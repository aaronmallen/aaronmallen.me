# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupReferrers < Blog::DB::Relation
      use :daily_rollup

      schema :analytics_rollup_referrers, infer: true

      ranks_by :host, nulls: :last
    end
  end
end

# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupPageReferrers < Blog::DB::Relation
      include DailyRollup

      schema :analytics_rollup_page_referrers, infer: true

      ranks_by :host
    end
  end
end

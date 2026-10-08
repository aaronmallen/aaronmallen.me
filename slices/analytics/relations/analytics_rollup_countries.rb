# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupCountries < Blog::DB::Relation
      use :daily_rollup

      schema :analytics_rollup_countries, infer: true

      ranks_by :country_code, nulls: :last
    end
  end
end

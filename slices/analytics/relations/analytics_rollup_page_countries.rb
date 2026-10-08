# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupPageCountries < Blog::DB::Relation
      use :daily_rollup

      schema :analytics_rollup_page_countries, infer: true

      ranks_by :country_code, named: :country_name
    end
  end
end

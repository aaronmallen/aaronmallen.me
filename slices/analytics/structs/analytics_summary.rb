# frozen_string_literal: true

module Analytics
  module Structs
    AnalyticsSummary = Data.define(
      :day, :totals, :paths, :referrers, :countries, :sources, :devices, :page_referrers, :page_countries,
    )
  end
end

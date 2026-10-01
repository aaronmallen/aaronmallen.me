# frozen_string_literal: true

module Analytics
  module Structs
    AnalyticsSummary = Data.define(:day, :totals, :paths, :referrers, :countries, :sources)
  end
end

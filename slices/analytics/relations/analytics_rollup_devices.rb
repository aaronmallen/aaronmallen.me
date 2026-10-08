# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupDevices < Blog::DB::Relation
      use :daily_rollup

      schema :analytics_rollup_devices, infer: true

      ranks_by :device_class
    end
  end
end

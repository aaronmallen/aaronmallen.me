# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsRollupDevices < Blog::DB::Relation
      include DailyRollup

      schema :analytics_rollup_devices, infer: true

      ranks_by :device_class
    end
  end
end

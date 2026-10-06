# frozen_string_literal: true

module Analytics
  module Queries
    class DevicesBetween
      include Deps[rollup_repo: "repos.analytics_rollup_repo", unrolled_summaries: "queries.unrolled_summaries"]

      def call(from:, to:, path: nil)
        rolled = rollup_repo.devices(from:, to:, path:).map(&:to_h)
        live = unrolled_summaries.call(from:, to:).flat_map(&:devices).select { it.fetch(:path) == path }

        RankedRows.call(rolled + live, key: :device_class)
      end
    end
  end
end

# frozen_string_literal: true

module Performance
  module Operations
    class RecordPageTiming < Blog::Operation
      include Deps[
        classify_device: "analytics.operations.classify_device",
        contract: "contracts.page_timing_contract",
        record_timing: "operations.record_timing",
      ]

      def call(timing, route:, user_agent:)
        found = step validated(contract.call(timing.is_a?(Hash) ? timing : {}))
        record_timing.call(:page, **found, route:, device_class: classify_device.call(user_agent))
      end
    end
  end
end

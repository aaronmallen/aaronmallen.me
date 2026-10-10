# frozen_string_literal: true

module Social
  module Jobs
    class ReapWebmentionReceipts < Blog::ScheduledJob
      include Deps[reap_webmention_receipts: "operations.reap_webmention_receipts"]

      def perform = reap_webmention_receipts.call
    end
  end
end

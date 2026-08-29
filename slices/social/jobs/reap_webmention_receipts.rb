# frozen_string_literal: true

module Social
  module Jobs
    class ReapWebmentionReceipts < Blog::Job
      include Deps[reap_webmention_receipts: "operations.reap_webmention_receipts"]

      sidekiq_options retry: false

      def perform = reap_webmention_receipts.call
    end
  end
end

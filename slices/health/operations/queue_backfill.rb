# frozen_string_literal: true

module Health
  module Operations
    class QueueBackfill
      def call = Jobs::BackfillHealth.perform_async(Blog::TimeZone.today.iso8601)
    end
  end
end

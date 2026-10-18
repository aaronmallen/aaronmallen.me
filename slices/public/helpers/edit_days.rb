# frozen_string_literal: true

module Public
  module Helpers
    module EditDays
      def self.newest_first(edits) = edits.group_by { Blog::TimeZone.local_date(it.created_at) }.to_a.reverse
    end
  end
end

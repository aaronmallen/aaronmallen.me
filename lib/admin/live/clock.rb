# frozen_string_literal: true

module Admin
  module Live
    module Clock
      KEY = "admin.live_at"

      def self.now = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
    end
  end
end

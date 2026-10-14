# frozen_string_literal: true

module Performance
  module Jobs
    class RollUpTiming < Blog::ScheduledJob
      include Deps[prune_timing: "operations.prune_timing", roll_up_timing: "operations.roll_up_timing"]

      def perform
        roll_up_timing.call
        prune_timing.call
      end
    end
  end
end

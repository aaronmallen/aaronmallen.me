# frozen_string_literal: true

module Record
  module Jobs
    class ReapSyncStates < Blog::ScheduledJob
      include Deps[reap_sync_states: "operations.reap_sync_states"]

      def perform = reap_sync_states.call
    end
  end
end

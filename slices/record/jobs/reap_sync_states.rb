# frozen_string_literal: true

module Record
  module Jobs
    class ReapSyncStates < Blog::Job
      include Deps[reap_sync_states: "operations.reap_sync_states"]

      sidekiq_options retry: false

      def perform = reap_sync_states.call
    end
  end
end

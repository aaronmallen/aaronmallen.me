# frozen_string_literal: true

module Security
  module Jobs
    class PruneAccessRecords < Blog::Job
      include Deps[prune_access_records: "operations.prune_access_records"]

      sidekiq_options retry: false

      def perform = prune_access_records.call
    end
  end
end

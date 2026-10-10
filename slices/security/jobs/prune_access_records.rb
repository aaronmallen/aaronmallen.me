# frozen_string_literal: true

module Security
  module Jobs
    class PruneAccessRecords < Blog::ScheduledJob
      include Deps[prune_access_records: "operations.prune_access_records"]

      def perform = prune_access_records.call
    end
  end
end

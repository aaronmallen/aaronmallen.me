# frozen_string_literal: true

module Health
  module Jobs
    class QueueHeldBackfills < Blog::ScheduledJob
      include Deps[health_mutations: "repos.health_mutations", health_queries: "repos.health_queries"]

      def perform = health_queries.held_backfills.each { queue(it) }

      private

      def queue(held)
        BackfillHealth.perform_async(held.last_day.iso8601)
        health_mutations.release_backfill(held.id)
      end
    end
  end
end

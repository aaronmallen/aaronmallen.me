# frozen_string_literal: true

module Activity
  module Repos
    class JobQueries
      DAYS = 7

      include Deps[
        history: "sidekiq.stats_history",
        processes: "sidekiq.processes",
        stats: "sidekiq.stats",
        timing_queries: "performance.repos.timing_queries",
      ]

      def flagged
        found = stats.call
        found.retry_size + found.dead_size
      rescue RedisClient::Error
        nil
      end

      def health
        Structs::JobHealth.from(
          stats: stats.call, history: history.call(DAYS), processes: processes.call.to_a,
          last_job_at: timing_queries.last_job_at,
        )
      rescue RedisClient::Error => e
        Structs::JobHealth.down(e)
      end
    end
  end
end

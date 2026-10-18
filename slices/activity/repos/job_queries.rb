# frozen_string_literal: true

module Activity
  module Repos
    class JobQueries
      DAYS = 7

      include Deps[
        history: "sidekiq.stats_history",
        processes: "sidekiq.processes",
        queue_jobs: "sidekiq.queue_jobs",
        queues: "sidekiq.queues",
        stats: "sidekiq.stats",
        timing_queries: "performance.repos.timing_queries",
        work: "sidekiq.work",
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

      def queue(name, page)
        found = queues.call.find { it.name == name && it.size.positive? }
        return unless found

        Structs::JobQueue.from(found, queued(found, page))
      rescue RedisClient::Error
        nil
      end

      def queue_list
        queues.call.map { Structs::JobQueue.from(it) }
      rescue RedisClient::Error
        []
      end

      def running
        works = work.call.group_by(&:first)

        processes.call.map { Structs::JobProcess.from(it, works.fetch(it.identity, []).map(&:last)) }
      rescue RedisClient::Error
        []
      end

      private

      def queued(found, page)
        rows = queue_jobs.call(found.name, page.number, page.size).map { Structs::JobEntry.from(it, it.enqueued_at) }

        Blog::Structs::Paged.new(rows:, number: page.number, more: found.size > page.offset + page.size)
      end
    end
  end
end

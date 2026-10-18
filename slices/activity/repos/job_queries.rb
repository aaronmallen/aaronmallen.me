# frozen_string_literal: true

module Activity
  module Repos
    class JobQueries
      DAYS = 7
      PEEK = Blog::Structs::Page.new(number: 1, size: 5)
      SETS = {
        "retries" => { key: "retry", size: :retry_size },
        "dead" => { key: "dead", size: :dead_size, reverse: true },
        "scheduled" => { key: "schedule", size: :scheduled_size },
      }.freeze

      include Deps[
        dead_set: "sidekiq.dead_set",
        history: "sidekiq.stats_history",
        processes: "sidekiq.processes",
        queue_jobs: "sidekiq.queue_jobs",
        retry_set: "sidekiq.retry_set",
        scheduled_set: "sidekiq.scheduled_set",
        set_jobs: "sidekiq.set_jobs",
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

      def overview(open:, page:, queue: nil)
        found = stats.call
        queues = found.queue_summaries.sort_by(&:name)
        present = processes.call.to_a

        {
          health: health(found, queues, present), running: running(present),
          queues: queues.map { Structs::JobQueue.from(it) },
          queue: (queued_in(queues, queue, page) if queue), sets: sets(found, open, page),
        }
      rescue RedisClient::Error => e
        { health: Structs::JobHealth.down(e) }
      end

      def set_job(name, jid)
        set = { "retries" => retry_set, "dead" => dead_set, "scheduled" => scheduled_set }.fetch(name)
        found = set.call.find_job(jid)
        Structs::SetJob.from(name, found) if found
      rescue RedisClient::Error
        nil
      end

      private

      def health(found, queues, present)
        Structs::JobHealth.from(
          stats: found, queues:, history: history.call(DAYS), processes: present,
          last_job_at: timing_queries.last_job_at,
        )
      end

      def queued(found, page)
        rows = queue_jobs.call(found.name, page.number, page.size).map { Structs::JobEntry.from(it, it.enqueued_at) }

        Blog::Structs::Paged.new(rows:, number: page.number, more: found.size > page.offset + page.size)
      end

      def queued_in(queues, name, page)
        found = queues.find { it.name == name && it.size.positive? }
        return unless found

        Structs::JobQueue.from(found, queued(found, page))
      rescue RedisClient::Error
        nil
      end

      def running(present)
        works = work.call.group_by(&:first)

        present.map { Structs::JobProcess.from(it, works.fetch(it.identity, []).map(&:last)) }
      rescue RedisClient::Error
        []
      end

      def set_page(name, size, page)
        set = SETS.fetch(name)
        rows = set_jobs.call(set[:key], page.number, page.size, reverse: set.fetch(:reverse, false))

        Blog::Structs::Paged.new(
          rows: rows.map { Structs::SetJob.from(name, it) }, number: page.number, more: size > page.offset + page.size,
        )
      end

      def sets(found, open, page)
        SETS.map do |name, set|
          size = found.public_send(set[:size])
          Structs::JobSet.new(name:, size:, jobs: set_page(name, size, name == open ? page : PEEK), all: name == open)
        end
      rescue RedisClient::Error
        []
      end
    end
  end
end

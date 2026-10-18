# frozen_string_literal: true

module Activity
  module Repos
    class JobQueries
      DAYS = 7
      PEEK = Blog::Structs::Page.new(number: 1, size: 5)
      SETS = {
        Blog::Types::JobSetName["retries"] => {
          container: "sidekiq.retry_set", key: "retry", size: :retry_size, newest_first: false,
          acts: %w[retry kill delete].freeze, primary: "retry",
        }.freeze,
        Blog::Types::JobSetName["dead"] => {
          container: "sidekiq.dead_set", key: "dead", size: :dead_size, newest_first: true,
          acts: %w[retry discard].freeze, primary: "retry",
        }.freeze,
        Blog::Types::JobSetName["scheduled"] => {
          container: "sidekiq.scheduled_set", key: "schedule", size: :scheduled_size, newest_first: false,
          acts: %w[run delete].freeze, primary: "run",
        }.freeze,
      }.freeze

      def self.set_deps = SETS.to_h { |name, set| [:"#{name}_set", set.fetch(:container)] }

      include Deps[
        **set_deps,
        history: "sidekiq.stats_history",
        processes: "sidekiq.processes",
        queue_jobs: "sidekiq.queue_jobs",
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
        found = sorted_sets.fetch(name).call.find_job(jid)
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
        rows = set_jobs.call(set[:key], page.number, page.size, reverse: set[:newest_first])

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

      def sorted_sets = SETS.keys.to_h { [it, public_send(:"#{it}_set")] }
    end
  end
end

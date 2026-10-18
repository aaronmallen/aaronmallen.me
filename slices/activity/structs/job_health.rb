# frozen_string_literal: true

module Activity
  module Structs
    JobHealth = Data.define(
      :status, :beat, :processes, :busy, :concurrency, :enqueued, :latency, :scheduled, :retries, :dead, :days,
      :last_job_at, :error,
    ) do
      def self.days(history)
        found = history.processed.map do |day, processed|
          { day: Date.parse(day), processed:, failed: history.failed[day] }
        end
        found.reverse
      end

      def self.down(error) = new(**members.to_h { [it, nil] }, error: "#{error.class}: #{error.message}")

      def self.from(stats:, history:, processes:, last_job_at:)
        latency = stats.queue_summaries.map(&:latency).max.to_f
        sets = { scheduled: stats.scheduled_size, retries: stats.retry_size, dead: stats.dead_size }

        new(**workers(processes), **sets, enqueued: stats.enqueued, latency:, days: days(history), last_job_at:,
                                          error: nil)
      end

      def self.status(processes)
        return :not_seen if processes.empty?
        return :stopping if processes.all?(&:stopping?)

        processes.sum { it["busy"] }.zero? ? :quiet : :working
      end

      def self.workers(processes)
        {
          status: status(processes), beat: processes.map { it["beat"] }.max&.then { Time.at(it) },
          processes: processes.size, busy: processes.sum { it["busy"] },
          concurrency: processes.sum { it["concurrency"] },
        }
      end

      def down? = !error.nil?

      def today = days.last
    end
  end
end

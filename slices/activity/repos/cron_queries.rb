# frozen_string_literal: true

module Activity
  module Repos
    class CronQueries
      include Deps[
        schedule: "sidekiq.schedule",
        states: "sidekiq.schedule_states",
        times: "sidekiq.schedule_times",
        timing_queries: "performance.repos.timing_queries",
      ]

      def entries
        last = last_runs
        redis = scheduler

        schedule.map { |name, entry| Structs::CronEntry.from(name, entry, last: last[key(entry)], **redis) }
                .sort_by(&:order)
      end

      def entry(name)
        found = schedule[name]
        return unless found

        last = timing_queries.last_scheduled_runs([key(found)])[key(found)]

        Structs::CronEntry.from(name, found, last:, **scheduler)
      end

      def failed
        last = last_runs

        schedule.each_value.count { last[key(it)]&.fetch(:outcome) == Structs::CronEntry::FAILED }
      end

      private

      def key(entry) = Object.const_get(entry.fetch("class")).check_in_name(*entry["args"])

      def last_runs = timing_queries.last_scheduled_runs(schedule.each_value.map { key(it) })

      def scheduler
        { next_times: times.call, states: states.call }
      rescue RedisClient::Error
        { next_times: nil, states: nil }
      end
    end
  end
end

# frozen_string_literal: true

module Health
  module Operations
    class QueueBackfill
      include Deps[health_mutations: "repos.health_mutations", honeybadger: "honeybadger.agent"]

      def call(last = Blog::TimeZone.today)
        Jobs::BackfillHealth.perform_async(last.iso8601)
      rescue RedisClient::Error => e
        honeybadger.notify(e)
        health_mutations.hold_backfill(last)
      end
    end
  end
end

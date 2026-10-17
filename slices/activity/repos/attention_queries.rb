# frozen_string_literal: true

module Activity
  module Repos
    class AttentionQueries < Blog::DB::Repo
      DEAD_JOB_LIMIT = 5

      include Deps["settings", dead_set: "sidekiq.dead_set"]

      def dead_job(jid)
        found = dead_set.call.find_job(jid)
        Structs::DeadJob.from(found) if found
      rescue RedisClient::Error
        nil
      end

      def dead_job_count
        dead_set.call.size
      rescue RedisClient::Error
        0
      end

      def dead_jobs(limit: DEAD_JOB_LIMIT, offset: 0)
        dead_set.call.lazy.drop(offset).first(limit).map { Structs::DeadJob.from(it) }
      rescue RedisClient::Error
        []
      end

      def listed?(kind:, record_id:) = attention.where(kind:, record_id:).exist?

      def stalled(now: Time.now, on: Blog::TimeZone.today(now))
        limits = settings.attention

        attention.stalled(on:, now:, **limits).to_a.map { Structs::StalledRow.from(it, on:, limits:) }.sort_by(&:rank)
      end
    end
  end
end

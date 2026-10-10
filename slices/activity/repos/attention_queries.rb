# frozen_string_literal: true

module Activity
  module Repos
    class AttentionQueries < DB::Repo
      include Deps["settings", dead_set: "sidekiq.dead_set"]

      def dead_jobs
        dead_set.call.map { Structs::DeadJob.from(it) }.sort_by { -it.died_at.to_f }
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

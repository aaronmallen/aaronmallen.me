# frozen_string_literal: true

module Activity
  module Repos
    class AttentionQueries < Blog::DB::Repo
      LIMIT = 5

      include Deps["settings", dead_set: "sidekiq.dead_set"]

      def capped(now: Time.now)
        rows = stalled(now:)
        kept = rows.group_by(&:kind).values.flat_map { it.first(LIMIT) }.sort_by(&:rank)

        { rows: kept, counts: Blog::Types::AttentionKind.values.to_h { [it, 0] }.merge(rows.map(&:kind).tally) }
      end

      def dead_job_count
        dead_set.call.size
      rescue RedisClient::Error
        0
      end

      def dead_jobs
        dead_set.call.first(LIMIT).map { Structs::SetJob.from("dead", it) }
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

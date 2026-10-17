# frozen_string_literal: true

module Health
  module Repos
    class HealthMutations < Blog::DB::Repo
      def hold_backfill(last_day) = held_health_backfills.hold(last_day)

      def release_backfill(id) = held_health_backfills.by_pk(id).delete

      def store(days:, workouts:, window:, now: Time.now)
        transaction do
          health_days.store(days, now:)
          self.workouts.prune(*window.minmax, keep: workouts.map { it[:google_id] })
          self.workouts.store(workouts, now:)
        end
        days.size + workouts.size
      end
    end
  end
end

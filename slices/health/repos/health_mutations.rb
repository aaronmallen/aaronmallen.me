# frozen_string_literal: true

module Health
  module Repos
    class HealthMutations < Blog::DB::Repo
      def store(days:, workouts:, now: Time.now)
        transaction do
          health_days.store(days, now:)
          self.workouts.store(workouts, now:)
        end
        days.size + workouts.size
      end
    end
  end
end

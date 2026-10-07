# frozen_string_literal: true

module Tasks
  module Operations
    class CurrentSprint < Operation
      include Deps[sprint_repo: "repos.sprint_repo"]

      def call(now: Time.now)
        transaction do
          sprint_repo.lock_roll_over
          sprint = sprint_repo.claim(Blog::TimeZone.today(now))
          arrived = sprint_repo.carry_forward(sprint.id, at: now)
          next sprint unless arrived.positive?

          sprint_repo.count_arrivals(sprint.id, arrived)
          step find(sprint.id)
        end
      end

      private

      def find(id)
        found(sprint_repo.by_id(id))
      end
    end
  end
end

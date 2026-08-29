# frozen_string_literal: true

module Tasks
  module Operations
    class CurrentSprint < Blog::Operation
      include Deps[sprint_repo: "repos.sprint_repo", task_repo: "repos.task_repo"]

      def call(now: Time.now)
        transaction do
          sprint = sprint_repo.claim(Blog::TimeZone.today(now))
          arrived = task_repo.carry_forward(sprint.id)
          next sprint unless arrived.positive?

          sprint_repo.count_arrivals(sprint.id, arrived)
          step find(sprint.id)
        end
      end

      private

      def find(id)
        sprint = sprint_repo.by_id(id)

        sprint ? Success(sprint) : Failure(:not_found)
      end
    end
  end
end

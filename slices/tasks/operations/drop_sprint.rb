# frozen_string_literal: true

module Tasks
  module Operations
    class DropSprint < Blog::Operation
      NEXT = Blog::Types::TaskList["next"]

      include Deps[sprint_repo: "repos.sprint_repo", task_repo: "repos.task_repo"]

      def call(id, now: Time.now)
        sprint = step find(id)
        step ahead(sprint, now)

        drop(sprint)
      end

      private

      def ahead(sprint, now) = sprint.sprint_date > Blog::TimeZone.today(now) ? Success(sprint) : Failure(:started)

      def drop(sprint)
        transaction do
          task_repo.release_sprint(sprint.id, list: NEXT)
          sprint_repo.delete(sprint.id)
        end

        sprint
      end

      def find(id)
        sprint = sprint_repo.by_id(id)

        sprint ? Success(sprint) : Failure(:not_found)
      end
    end
  end
end

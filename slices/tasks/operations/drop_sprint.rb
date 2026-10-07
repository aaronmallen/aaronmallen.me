# frozen_string_literal: true

module Tasks
  module Operations
    class DropSprint < Operation
      include Deps[sprint_mutations: "repos.sprint_mutations", sprint_queries: "repos.sprint_queries"]

      def call(id, now: Time.now)
        sprint = step find(id)
        step ahead(sprint, now)

        drop(sprint, now)
      end

      private

      def ahead(sprint, now) = sprint.sprint_date > Blog::TimeZone.today(now) ? Success(sprint) : Failure(:started)

      def drop(sprint, now)
        transaction do
          sprint_mutations.release(sprint.id, at: now)
          sprint_mutations.delete(sprint.id)
        end

        sprint
      end

      def find(id)
        found(sprint_queries.by_id(id))
      end
    end
  end
end

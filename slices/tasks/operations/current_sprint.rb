# frozen_string_literal: true

module Tasks
  module Operations
    class CurrentSprint < Blog::Operation
      include Deps[sprint_mutations: "repos.sprint_mutations", sprint_queries: "repos.sprint_queries"]

      def call(now: Time.now)
        sprint = sprint_queries.on(Blog::TimeZone.local_date(now))
        return sprint if sprint && sprint_queries.settled?(sprint.id)

        roll_over(now)
      end

      private

      def find(id)
        found(sprint_queries.by_id(id))
      end

      def roll_over(now)
        transaction do
          sprint_mutations.lock_roll_over
          sprint = sprint_mutations.claim(Blog::TimeZone.local_date(now))
          arrived = sprint_mutations.carry_forward(sprint.id, at: now)
          next sprint unless arrived.positive?

          sprint_mutations.count_arrivals(sprint.id, arrived)
          step find(sprint.id)
        end
      end
    end
  end
end

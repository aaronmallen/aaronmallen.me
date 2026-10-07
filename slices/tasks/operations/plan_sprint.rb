# frozen_string_literal: true

module Tasks
  module Operations
    class PlanSprint < Operation
      include Deps[sprint_mutations: "repos.sprint_mutations", sprint_queries: "repos.sprint_queries"]

      def call(date, now: Time.now)
        day = step parse(date)
        step ahead(day, now)
        step unplanned(day)

        sprint_mutations.claim(day)
      end

      private

      def ahead(day, now) = day > Blog::TimeZone.today(now) ? Success(day) : Failure(:past)

      def parse(date)
        day = Blog::TimeZone.parse_day(date)

        day ? Success(day) : Failure(:invalid)
      end

      def unplanned(day) = sprint_queries.on(day) ? Failure([:planned, day]) : Success(day)
    end
  end
end

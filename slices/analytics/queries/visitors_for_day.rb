# frozen_string_literal: true

module Analytics
  module Queries
    class VisitorsForDay
      include Deps[event_repo: "repos.analytics_event_repo"]

      def call(day) = event_repo.visitors_on(day)
    end
  end
end

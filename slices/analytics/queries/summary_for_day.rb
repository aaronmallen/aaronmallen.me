# frozen_string_literal: true

module Analytics
  module Queries
    class SummaryForDay
      include Deps[event_repo: "repos.analytics_event_repo"]

      def call(day) = event_repo.summary_for(day)
    end
  end
end

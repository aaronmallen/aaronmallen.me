# frozen_string_literal: true

module Decisions
  module Queries
    class Timeline
      include Deps[decision_timeline_repo: "repos.decision_timeline_repo"]

      def call(decision_id) = decision_timeline_repo.for_decision(decision_id)
    end
  end
end

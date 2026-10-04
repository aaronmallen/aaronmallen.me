# frozen_string_literal: true

module Decisions
  module Repos
    class DecisionTimelineRepo < Blog::DB::Repo
      def for_decision(decision_id) = decision_timeline.for_decision(decision_id).oldest_first.to_a
    end
  end
end

# frozen_string_literal: true

module Decisions
  module Relations
    class DecisionTimeline < Blog::DB::Relation
      schema :decision_timeline, infer: true

      def for_decision(decision_id) = where(decision_id:)

      def oldest_first = order(self[:occurred_at].asc, self[:kind].asc, self[:source_id].asc)
    end
  end
end

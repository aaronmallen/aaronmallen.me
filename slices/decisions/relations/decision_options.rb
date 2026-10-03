# frozen_string_literal: true

module Decisions
  module Relations
    class DecisionOptions < Blog::DB::Relation
      schema :decision_options, infer: true do
        associations do
          belongs_to :decision
        end
      end

      def for_decision(decision_id) = where(decision_id:)

      def in_order = order(self[:created_at].asc, self[:id].asc)
    end
  end
end

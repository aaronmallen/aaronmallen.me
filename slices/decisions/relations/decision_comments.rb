# frozen_string_literal: true

module Decisions
  module Relations
    class DecisionComments < Blog::DB::Relation
      schema :decision_comments, infer: true do
        associations do
          belongs_to :decision
        end
      end

      def for_decision(decision_id) = where(decision_id:)
    end
  end
end

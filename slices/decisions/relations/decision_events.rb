# frozen_string_literal: true

module Decisions
  module Relations
    class DecisionEvents < Blog::DB::Relation
      schema :decision_events, infer: true do
        associations do
          belongs_to :decision
        end
      end
    end
  end
end

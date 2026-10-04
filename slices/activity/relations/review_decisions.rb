# frozen_string_literal: true

module Activity
  module Relations
    class ReviewDecisions < Blog::DB::Relation
      schema :review_decisions, infer: true

      def closed_between(from, to)
        where(closed_on: from..to).order(self[:closed_at].asc, self[:event_id].asc)
      end
    end
  end
end

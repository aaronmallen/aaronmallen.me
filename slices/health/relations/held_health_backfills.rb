# frozen_string_literal: true

module Health
  module Relations
    class HeldHealthBackfills < Blog::DB::Relation
      schema :held_health_backfills, infer: true

      def hold(last_day) = dataset.insert_conflict.insert(last_day:)

      def oldest_first = order(self[:id].asc)
    end
  end
end

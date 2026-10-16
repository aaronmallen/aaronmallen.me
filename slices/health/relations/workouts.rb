# frozen_string_literal: true

module Health
  module Relations
    class Workouts < Blog::DB::Relation
      COLUMNS = %i[
        kind started_at minutes distance_meters average_heart_rate zone_minutes kcal device updated_at
      ].freeze

      schema :workouts, infer: true

      def between(first, last) = starting(first, last).order(self[:started_at].asc, self[:id].asc)

      def prune(first, last, keep:) = starting(first, last).exclude(google_id: keep).delete

      def store(rows, now:)
        rows = rows.map { it.merge(created_at: now, updated_at: now) }

        dataset.insert_conflict(target: :google_id, update: excluded(COLUMNS)).multi_insert(rows)
      end

      private

      def starting(first, last)
        from, to = Blog::TimeZone.day_bounds(first, last)

        where(self[:started_at] >= from).where(self[:started_at] < to)
      end
    end
  end
end

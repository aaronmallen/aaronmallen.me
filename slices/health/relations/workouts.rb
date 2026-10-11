# frozen_string_literal: true

module Health
  module Relations
    class Workouts < Blog::DB::Relation
      COLUMNS = %i[
        kind started_at minutes distance_meters average_heart_rate zone_minutes kcal device updated_at
      ].freeze

      schema :workouts, infer: true

      def store(rows, now:)
        rows = rows.map { it.merge(created_at: now, updated_at: now) }

        dataset.insert_conflict(target: :google_id, update: excluded(COLUMNS)).multi_insert(rows)
      end
    end
  end
end

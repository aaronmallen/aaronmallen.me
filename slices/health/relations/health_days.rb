# frozen_string_literal: true

module Health
  module Relations
    class HealthDays < Blog::DB::Relation
      COLUMNS = %i[minutes_asleep bed_at woke_at resting_heart_rate hrv steps active_zone_minutes updated_at].freeze

      schema :health_days, infer: true

      def store(rows, now:)
        rows = rows.map { it.merge(created_at: now, updated_at: now) }

        dataset.insert_conflict(target: :day, update: excluded(COLUMNS)).multi_insert(rows)
      end
    end
  end
end

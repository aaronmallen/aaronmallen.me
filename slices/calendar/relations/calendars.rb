# frozen_string_literal: true

module Calendar
  module Relations
    class Calendars < Blog::DB::Relation
      COLUMNS = %i[name writable updated_at].freeze

      schema :calendars, infer: true

      def in_list_order = order(self[:account], self[:id])

      def store(account, rows, now:)
        return {} if rows.empty?

        rows = rows.map { it.merge(account:, created_at: now, updated_at: now) }

        upsert = dataset.insert_conflict(target: %i[account google_id], update: excluded(COLUMNS))

        upsert.returning(:google_id, :id).multi_insert(rows).to_h { it.values_at(:google_id, :id) }
      end
    end
  end
end

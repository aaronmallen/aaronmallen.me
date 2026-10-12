# frozen_string_literal: true

module Calendar
  module Relations
    class CalendarEvents < Blog::DB::Relation
      COLUMNS = %i[title starts_on ends_on starts_at ends_at place meet_url attendees notes link updated_at].freeze

      schema :calendar_events, infer: true do
        associations { belongs_to :calendar }
      end

      def between(from, to) = where { (starts_on <= to) & (ends_on >= from) }

      def in_day_order = order(self[:starts_at].asc(nulls: :first), self[:title], self[:id])

      def store(rows, now:)
        rows = rows.map do |row|
          row.merge(attendees: Sequel.pg_array(row[:attendees], :text), created_at: now, updated_at: now)
        end

        dataset.insert_conflict(target: %i[calendar_id google_id], update: excluded(COLUMNS)).multi_insert(rows)
      end
    end
  end
end

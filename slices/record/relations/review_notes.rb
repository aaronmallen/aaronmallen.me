# frozen_string_literal: true

module Record
  module Relations
    class ReviewNotes < Blog::DB::Relation
      KEY = %i[period starts_on].freeze

      schema :review_notes, infer: true

      def of(period, starts_on) = where(period:, starts_on:)

      def save_note(period:, starts_on:, body:, now:)
        update = excluded(%i[body updated_at])

        upsert({ period:, starts_on:, body:, created_at: now, updated_at: now }, target: KEY, update:)
      end
    end
  end
end

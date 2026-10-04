# frozen_string_literal: true

module Record
  module Relations
    class ReviewNotes < Blog::DB::Relation
      schema :review_notes, infer: true

      def of(period, starts_on) = where(period:, starts_on:)
    end
  end
end

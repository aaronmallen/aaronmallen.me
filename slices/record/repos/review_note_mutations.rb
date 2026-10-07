# frozen_string_literal: true

module Record
  module Repos
    class ReviewNoteMutations < DB::Repo
      def save_note(period:, starts_on:, body:, now:)
        review_notes.save_note(period:, starts_on:, body:, now:)
        review_notes.of(period, starts_on).one
      end
    end
  end
end

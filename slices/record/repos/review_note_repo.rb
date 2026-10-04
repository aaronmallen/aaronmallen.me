# frozen_string_literal: true

module Record
  module Repos
    class ReviewNoteRepo < Blog::DB::Repo
      def note(period, starts_on) = review_notes.of(period, starts_on).one

      def save_note(period:, starts_on:, body:, now:)
        review_notes.save_note(period:, starts_on:, body:, now:)
        note(period, starts_on)
      end
    end
  end
end

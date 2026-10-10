# frozen_string_literal: true

module Record
  module Repos
    class ReviewNoteQueries < Blog::DB::Repo
      def note(period, starts_on) = review_notes.of(period, starts_on).one
    end
  end
end

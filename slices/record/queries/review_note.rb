# frozen_string_literal: true

module Record
  module Queries
    class ReviewNote
      include Deps[review_note_repo: "repos.review_note_repo"]

      def call(period, starts_on) = review_note_repo.entry(period, starts_on)
    end
  end
end

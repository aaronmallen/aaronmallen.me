# frozen_string_literal: true

module Record
  module Queries
    class ReviewNote
      include Deps[journal_entry_repo: "repos.journal_entry_repo"]

      def call(on) = journal_entry_repo.tagged_on(Operations::SaveReviewNote::TAG, on)
    end
  end
end

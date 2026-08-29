# frozen_string_literal: true

module Activity
  module Queries
    class ActivityCounts
      include Deps[activity_repo: "repos.activity_repo"]

      def call(from:, to:, **filters) = activity_repo.counts(from:, to:, **filters)
    end
  end
end

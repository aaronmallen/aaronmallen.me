# frozen_string_literal: true

module Activity
  module Queries
    class ActivityCountsByMonth
      include Deps[activity_repo: "repos.activity_repo"]

      def call(from:, to:, **filters) = activity_repo.counts_by_month(from:, to:, **filters)
    end
  end
end
